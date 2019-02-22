#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[fs path]>
require! <[async lodash request]>
moment = require \moment-timezone
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename
{Broker} = require \../common/broker
{escape} = require \influx/lib/src/grammar/escape


const DEFAULTS =
  url: \https://ifdb.tic-tac-toe.io
  username: \root
  password: \root
  health_checking_timeout: 5s
  data_writing_timeout: 30s

const MEASUREMENT_NAME_SEPARATOR = "."
const BAD_FIELD_VALUES = <[true false on off null]>


#
# Refer to https://docs.influxdata.com/influxdb/v1.3/write_protocols/line_protocol_reference/
#
#   "Double quote string field values. Do not double quote floats, integers, or booleans."
#
QUOTED_STRING = (x) ->
  t = typeof x
  return x if t is \number
  return x if t is \boolean
  return escape.quoted x


IS_VALID = (name, k, v) ->
  t = typeof v
  return yes if t is \number
  return yes if t is \boolean
  if t is \string
    return yes unless v in BAD_FIELD_VALUES
    ERR "#{name} => #{k}=#{v}, bad value"
    return no
  else
    WARN "#{name} => #{k}=type(#{t})"
    return no


NULL_WITH_WARNING = (message) ->
  WARN message
  return null


TO_LINE = (epoch, name, tags, kvs) ->
  xs = [ "#{t}=#{v}" for t, v of tags when v? and (IS_VALID name, t, v) ]
  xs = [name] ++ xs
  metadata = xs.join ","
  ys = [ "#{k}=#{QUOTED_STRING v}" for k, v of kvs when v? and (IS_VALID name, k, v) ]
  return NULL_WITH_WARNING "#{name} => #{JSON.stringify tags} => no fields to be inserted => #{JSON.stringify kvs}" if ys.length is 0
  fields = ys.join ","
  zs = [metadata, fields, "#{epoch}" ]
  result = zs.join " "
  return result


MEASUREMENT_TO_LINE = (id, measurement) ->
  [timestamp, p_type, p_id, s_type, s_id, kvs] = measurement
  peripheral_type = p_type
  peripheral_id = p_id
  sensor_type = s_type
  sensor_id = s_id
  tokens = [id, peripheral_type, sensor_type]
  name = tokens.join MEASUREMENT_NAME_SEPARATOR
  tags = {peripheral_id, sensor_id}
  return TO_LINE timestamp, name, tags, kvs


/**
 *
context:
  {
    "source": "toe3-upload",
    "upload": {
      "filename": "00040-00129FA8C3-1550658885368-20190220-193445.json.gz",
      "compressedSize": 59429,
      "rawSize": 255125
    },
    "timestamps": {
      "measured": 1550657682460,
      "received": 1550845599674,
      "transformed": 1550845599702,
      "delta": 1967
    }
  }
 */
CONTEXT_TO_LINE = (node, measurements, context={}) ->
  tags = {node}
  now = new Date! - 0
  {source, upload, timestamps} = context
  size = upload.compressedSize
  raw_size = upload.rawSize
  epoch_time_delta = timestamps.delta
  ip = null
  num_of_measurements = measurements.length
  num_of_points = null
  line = TO_LINE now, "sensorhub.upload", tags, {size, raw_size, epoch_time_delta, ip, num_of_measurements, num_of_points}
  #
  # For direct api upload, the `context` shall be:
  #
  #   source: \tic3-rest
  #   upload:
  #     filename: \api
  #     compressedSize: HTTP.content-length
  #     rawSize: HTTP.content-length
  #   timestamps:
  #     measured: The timestamp of last one of measurements
  #     received: NOW
  #     transformed: NOW
  #     delta: 0
  #
  return line



class InfluxdbWriter extends Broker
  (@parent, @environment, @helpers, configs) ->
    @defaults = DEFAULTS
    super ...
    {url, username, password} = @configs
    @url = url
    @username = username
    @password = password
    return

  init: (done) ->
    {url, username, password} = self = @
    return done "missing url in influxdb-1x-writer broker configs" unless url? and \string is typeof url
    return done "missing username in influxdb-1x-writer broker configs" unless username? and \string is typeof username
    return done "missing password in influxdb-1x-writer broker configs" unless password? and \string is typeof password
    return done!

  check-health: (done) ->
    {prefix, url, health_checking_timeout} = self = @
    timeout = health_checking_timeout
    method = \HEAD
    url = "#{url}/ping"
    opts = {url, method, timeout}
    INFO "#{prefix} checking healthy... (#{JSON.stringify opts})"
    (err, rsp, body) <- request opts
    if err?
      WARN err, "#{prefix} using OPTIONS to check #{url}, but failed"
      return done err, no
    else if rsp.statusCode isnt 204
      WARN "#{prefix} using HEAD to ping #{url}, but failed with non-204 response: #{rsp.statusCode} (#{rsp.statusMessage.red})"
      return done null, no
    else
      INFO "#{prefix} using HEAD to ping #{url} and success"
      return done null, yes

  proceed: (profile, id, measurements, context, done) ->
    {prefix, verbose, url, username, password, data_writing_timeout} = self = @
    timestamp = context.timestamps.measured
    num_of_measurements = measurements.length.toString!
    xs = [ (MEASUREMENT_TO_LINE id, m) for m in measurements ]
    xs.push CONTEXT_TO_LINE id, measurements, context
    xs = [ x for x in xs when x? ]
    body = xs.join "\n"
    uri = "#{url}/write"
    u = username
    p = password
    db = profile
    precision = \ms
    qs = {u, p, db, precision}
    req = {uri, qs, body}
    INFO "#{prefix} submits #{profile}/#{id}/#{timestamp} - #{num_of_measurements.magenta} measurements to #{uri.cyan}" if verbose
    console.log [ "\t#{x}" for x in xs ].join '\n' if verbose
    start = Date.now!
    (err, rsp, body) <- request.post req
    if err?
      ERR err, "#{prefix} fails to write measurements to #{uri}"
      return done err, no
    else if rsp.statusCode isnt 204
      {statusCode, statusMessage} = rsp
      if statusCode is 401
        WARN "#{prefix} gets server response #{statusCode} (#{statusMessage.red})"
        return done statusMessage
      else
        switch statusCode
        | 400       => WARN "#{prefix} gets server response #{statusCode} (#{statusMessage.red}) => line protocol syntax error => #{body.toString!.gray}"
        | 404       => WARN "#{prefix} gets server response #{statusCode} (#{statusMessage.red}) => database is missing => #{body.toString!.gray}"
        | 500       => WARN "#{prefix} gets server response #{statusCode} (#{statusMessage.red}) => server overloaded => #{body.toString!.gray}"
        | otherwise => WARN "#{prefix} gets server response #{statusCode} (#{statusMessage.red}) => unknown error"
        return done statusMessage
    else
      duration = (Date.now! - start).toString!
      INFO "#{prefix} submits #{profile}/#{id}/#{timestamp} - #{num_of_measurements.magenta} measurements successfully (#{duration.green}ms)"
      return done!



module.exports = exports = InfluxdbWriter
