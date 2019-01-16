#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[path async lodash request]>
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename
{constants} = require \../common/definitions
{APPEVT_TIME_SERIES_V1_DATA_POINTS, APPEVT_TIME_SERIES_V3_MEASUREMENTS} = constants


class DataPack
  (@profile, @id, @measurements, @context) ->
    @data = {profile, id, context, measurements}
    @data-raw = new Buffer JSON.stringify @data
    @data-compressed = null
    return

  get-data: (compressed, done) ->
    {data, data-raw, data-compressed} = self = @
    return done null, data-compressed if compressed and data-compressed?
    return done null, data if not compressed
    (err, z) <- zlib.gzip data
    return done err if err?
    self.data-compressed = z
    self.ratio = (z.length * 100 / data.length).toFixed 2
    return done null, z


class Forwarder
  (@manager, @opts, @verbose) ->
    @name = opts.name
    @prefix = "forwarders[#{@name.cyan}]"
    @compressed = opts.compressed
    @compressed = no unless @compressed? and \boolean is typeof @compressed
    @url = opts.url
    @request_opts = opts.request_opts
    return

  forward: (pack, done) ->
    {prefix, compressed, url, request_opts} = self = @
    {profile, id, measurements, context} = pack
    timestamp = context.timestamps.measured
    timestamp = (new Date timestamp) - 0
    num_of_measurements = "#{measurements.length}"
    method = \POST
    qs = {profile, id, timestamp}
    json = if compressed then no else yes
    c = if compressed then "json.gz" else "json"
    opts = lodash.merge {}, request_opts, {method, json, url, qs}
    INFO "opts: #{JSON.stringify opts}"
    (pack-err, data) <- pack.get-data compressed
    return done pack-err if pack-err?
    bytes = "#{data.length}"
    if compressed
      INFO "..."
    else
      opts['body'] = data
      opts['headers'] = {'content-type': 'application/json'}
    (http-err, rsp, body) <- request opts
    return done "failed to send #{profile}/#{id}/#{timestamp} data to #{url} => #{http-err}" if http-err?
    return done "failed to send #{profile}/#{id}/#{timestamp} data to #{url} because of non-200 response code: #{rsp.statusCode}" unless rsp.statusCode is 200
    INFO "#{prefix}: #{profile}/#{id}/#{timestamp}: forward #{num_of_measurements.magenta} measurements (#{c}) successfully (#{bytes.blue} bytes)"
    return done!



class ForwardManager
  (@environment, @configs, @helpers, @app) ->
    self = @
    self.verbose = configs.verbose
    self.verbose = no unless \boolean is typeof self.verbose
    self.forwarders = [ (new Forwarder self, d, self.verbose) for d in configs.destinations when d.enabled? and d.enabled ]
    return

  init: (done) ->
    {app} = self = @
    app.on APPEVT_TIME_SERIES_V3_MEASUREMENTS, -> self.at-ts-v3-measurements.apply self, arguments
    return done!

  at-ts-v3-measurements: (profile, id, measurements, context) ->
    {forwarders} = self = @
    pack = new DataPack profile, id, measurements, context
    for f in forwarders
      (err) <- f.forward pack
      ERR err, "forwarding failure" if err?
    return

/*
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
  name: \http-forwarder

  attach: (name, environment, configs, helpers) ->
    app = @
    broker = app[name] = new ForwardManager environment, configs, helpers, app
    return null

  init: (p, done) ->
    return p.init done

  fini: (p, done) ->
    return done!

