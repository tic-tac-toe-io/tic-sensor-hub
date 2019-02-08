#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[path async lodash]>
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename
{constants} = require \../common/definitions
{APPEVT_TIME_SERIES_V1_DATA_POINTS, APPEVT_TIME_SERIES_V3_MEASUREMENTS} = constants

const ONE_MONTH = 30 * 24 * 60 * 60 * 1000
const ONE_HOUR = 60 * 60 * 1000


class DataNode
  (@profile, @id, @p, @verbose=no) ->
    @kvs = {}
    @updated_at = null
    @time_shifts = null
    return

  show-message: (message) ->
    {profile, id, p, verbose} = self = @
    return unless verbose
    INFO "[#{id.yellow}] #{p.green} => #{message.gray}"

  update: (updated_at, data_type, value, time_shifts) ->
    {kvs} = self = @
    d1 = {updated_at, data_type, value, time_shifts}
    if not self.updated_at?
      self.updated_at = updated_at
      self.time_shifts = time_shifts
    d0 = kvs[data_type]
    self.show-message "#{data_type}: ignore old value `#{d0.value}` at #{d0.updated_at}ms" if d0?
    kvs[data_type] = d1

  serialize: ->
    {updated_at, p, kvs, time_shifts} = self = @
    # ys = [ "#{ts}" for ts in time_shifts ]
    # ys = ys.join ','
    ks = { [k, v.value] for k, v of kvs }
    # pairs = JSON.stringify ks
    pairs = [ "#{k}=#{v}" for k, v of ks ]
    xs = ["#{updated_at}", p] ++ pairs
    return xs.join '\t'

  serialize-v3: ->
    {updated_at, p, kvs} = self = @
    field_set = { [k, v.value] for k, v of kvs }
    [p_type, p_id, s_type, s_id] = p.split '/'
    epoch = updated_at
    return [epoch, p_type, p_id, s_type, s_id, field_set]


class DataAggregatorV3
  (@profile, @id, @verbose=no) ->
    @pathes = {}
    return

  show-message: (message, ret=no, p="") ->
    {profile, id, verbose} = self = @
    return unless verbose
    INFO "[#{id.yellow}.#{updated_at}] #{p.green} => #{message.gray}"
    return ret

  update: (@items) ->
    {profile, id, pathes, verbose} = self = @
    for i in items
      [updated_at, board_type, board_id, sensor, data_type, value, time_shifts] = i
      ##
      # Transform from TIC/DG1 schema to TIC/DG3 schema from
      #   {board_type, board_id, sensor}
      # to
      #   {p_type, p_id, s_type, s_id}
      #
      p_type = board_type
      p_id = board_id
      if -1 is sensor.indexOf ':'
        s_type = sensor
        s_id = \0
      else
        [s_type, s_id] = sensor.split ':'
      p = "#{p_type}/#{p_id}/#{s_type}/#{s_id}"
      node = pathes[p]
      node = new DataNode profile, id, p, verbose unless node?
      node.update updated_at, data_type, value, time_shifts
      pathes[p] = node

  serialize: ->
    {pathes} = self = @
    return [ (node.serialize-v3!) for p, node of pathes ]



class DataItemV1
  (@profile, @id, @item, @verbose) ->
    {desc, data} = item
    {board_type, board_id, sensor, data_type} = desc
    {updated_at, value, type, unit_length} = data
    @invalid = yes
    return unless board_type? and \string is typeof board_type
    return unless board_id? and \string is typeof board_id
    return unless sensor? and \string is typeof sensor
    return unless data_type? and \string is typeof data_type
    return unless updated_at? and \string is typeof updated_at
    @now = now = (new Date!) - 0
    updated_at = Date.parse updated_at
    return if updated_at === NaN
    @board_type = board_type
    @board_id = board_id
    @sensor = sensor
    @data_type = data_type
    @updated_at = updated_at
    @time_shift = ts = now - updated_at
    @time_shifts = [ts]
    @type = type
    @invalid = no
    p = "#{board_type}/#{board_id}/#{sensor}/#{data_type}"
    @prefix = "[#{id.yellow}.#{updated_at}] #{p.green}"
    value = parseFloat value.toFixed 2 if \process is board_type and \number is type
    @value = value

  show-message: (message, ret=no) ->
    {verbose} = self = @
    return unless verbose
    INFO "#{@prefix} => #{message.gray}"
    return ret

  is-broadcastable: ->
    {invalid, board_type, board_id, sensor, data_type, updated_at, now, value, type, time_shift, now} = @
    return @.show-message "invalid data item" if invalid
    return @.show-message "value is NULL" unless value?
    return @.show-message "value is STRING" if \string is typeof value
    return @.show-message "data comes from future (at least one hour later). #{updated_at} v.s. #{now}" if (time_shift + ONE_HOUR) < 0
    return @.show-message "data came from one month ago. #{updated_at} v.s. #{now}" if time_shift > ONE_MONTH
    return yes
    # [TODO]
    # 1. ignore when the value isn't changed, for past 60 seconds
    # 2. transform to new schema
    # 3. chain to next server

  to-array: ->
    {board_type, board_id, sensor, data_type, updated_at, value, time_shifts} = self = @
    return [updated_at, board_type, board_id, sensor, data_type, value, time_shifts]


class Transform
  (@environment, @configs, @helpers, @app) ->
    self = @
    self.verbose = configs.verbose
    self.verbose = no unless \boolean is typeof self.verbose
    return

  init: (done) ->
    {app} = self = @
    app.on APPEVT_TIME_SERIES_V1_DATA_POINTS, -> self.at-ts-v1-points.apply self, arguments
    return done!

  at-ts-v1-points: (profile, id, items, context) ->
    {app, verbose, forwarders} = self = @
    return unless items? and Array.isArray items and items.length > 0
    {received} = context.timestamps

    xs = [ (new DataItemV1 profile, id, i, verbose) for i in items ]
    ys = [ (x.to-array!) for x in xs when x.is-broadcastable! ]
    da = new DataAggregatorV3 profile, id, verbose
    da.update ys
    measurements = da.serialize yes

    ctx = lodash.merge {}, context
    transformed = ctx.timestamps.transformed = (new Date!) - 0
    duration = transformed - received

    {filename, compressed-size} = context.upload
    num_of_items = "#{items.length}"
    num_of_measurements = "#{measurements.length}"
    compressed = "#{compressed-size}"
    INFO "#{profile.cyan}/#{id.yellow}/#{filename.green} => from #{num_of_items.red} items to #{num_of_measurements.magenta} measurements. (json.gz: #{compressed.blue} bytes)" if verbose
    return app.emit APPEVT_TIME_SERIES_V3_MEASUREMENTS, profile, id, measurements, ctx

    /*
    if verbose
      [ console.log "\t#{d}" for d in ds ]
    data = ds.join '\n'
    csv-bytes = data.length
    ratio = (csv-bytes * 100 / json-bytes).toFixed 2
    json-gz-bytes = "#{json-gz-bytes}"
    json-bytes = "#{json-bytes}"
    csv-bytes = "#{data.length}"
    INFO "#{profile.cyan}/#{id.yellow}/#{filename.green} => text compact from #{json-bytes.magenta} to #{csv-bytes.magenta} bytes (#{ratio.red}%)"
    csv-buffer = new Buffer data
    (err, gz-buffer) <- zlib.gzip csv-buffer
    csv-gz-bytes = "#{gz-buffer.length}"
    INFO "#{profile.cyan}/#{id.yellow}/#{filename.green} => archive compact from #{json-gz-bytes.magenta} to #{csv-gz-bytes.magenta} bytes (#{ratio.red}%)"
    for f in forwarders
      f.forward profile, id, csv-buffer, gz-buffer
    return
    */



module.exports = exports =
  name: \1to3

  attach: (name, environment, configs, helpers) ->
    app = @
    broker = app[name] = new Transform environment, configs, helpers, app
    return null

  init: (p, done) ->
    return p.init done

  fini: (p, done) ->
    return done!
