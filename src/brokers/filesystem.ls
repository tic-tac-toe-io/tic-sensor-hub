#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[fs path zlib]>
require! <[async lodash mkdirp]>
moment = require \moment-timezone
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename
{Broker} = require \../common/broker

const DEFAULTS =
  path: \/tmp
  flush_threashold: 20


SERIALIZE_MEASUREMENT = (m) ->
  [timestamp, p_type, p_id, s_type, s_id, kv] = m
  timestamp = timestamp.toString!
  kv = JSON.stringify kv
  xs = [timestamp, p_type, p_id, s_type, s_id, kv]
  return xs.join '\t'


class DataPack
  (@broker, @profile, @id) ->
    @data = []
    return

  add-measurements: (measurements, context) ->
    {data} = self = @
    data.push {measurements, context}

  need-flush: ->
    return @data.length >= @broker.flush_threashold

  flush: ->
    {broker, data, profile, id} = self = @
    {dir, environment} = broker
    {process_name} = environment
    now = moment!
    filename = "#{profile}-#{id}-#{process_name}-#{now.valueOf!}.csv"
    filepath = "#{dir}/#{now.format 'YYYYMMDD-HH'}/#{filename}"
    xs = [ d.measurements for d in data ]
    xs = lodash.flatten xs
    xs = [ (SERIALIZE_MEASUREMENT x) for x in xs ]
    text = xs.join '\n'
    p = path.dirname filepath
    (mkdirp-err) <- mkdirp p
    return ERR mkdirp-err, "#{broker.prefix} fails to create directory #{p.yellow}" if mkdirp-err?
    (write-err) <- fs.writeFile filepath, text
    return ERR write-err, "#{broker.prefix} fails to write #{filepath.yellow}" if write-err?
    return INFO "#{broker.prefix} successfully writes to #{filepath.yellow}"


class Filesystem extends Broker
  (@parent, @environment, @helpers, configs) ->
    @defaults = DEFAULTS
    super ...
    @dir = @configs['path']
    @flush_threashold = @configs['flush_threashold']
    @caches = {}
    return

  init: (done) ->
    {prefix, dir, configs} = self = @
    (err) <- mkdirp dir
    return done err if err?
    INFO "#{prefix} create directory #{dir} successfully."
    return done!

  proceed: (profile, id, measurements, context, done) ->
    {dir, caches} = self = @
    done!
    key = "#{profile}:#{id}"
    obj = caches[key]
    obj = new DataPack self, profile, id unless obj?
    obj.add-measurements measurements, context
    caches[key] = obj
    return unless obj.need-flush!
    delete caches[key]
    return obj.flush!


module.exports = exports = Filesystem
