#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[path zlib]>
require! <[async lodash request]>
moment = require \moment-timezone
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename
{Broker} = require \../common/broker

const DEFAULTS =
  url: null
  url_appending: no
  compressed: no
  snapshot: no
  health_checking_timeout: 10s
  data_forwarding_timeout: 30s
  request_opts: {}


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
    (err, z) <- zlib.gzip data-raw
    return done err if err?
    self.data-compressed = z
    self.ratio = (z.length * 100 / data-raw.length).toFixed 2
    return done null, z


class HttpForwarder extends Broker
  (@parent, @environment, @helpers, configs) ->
    @defaults = DEFAULTS
    super ...
    {url, url_appending, compressed, snapshot, health_checking_timeout, data_forwarding_timeout, request_opts} = @configs
    @url = url
    @url_appending = url_appending
    @compressed = compressed
    @snapshot = snapshot
    @request_opts = request_opts
    @health_checking_timeout = health_checking_timeout
    @data_forwarding_timeout = data_forwarding_timeout
    return

  check-health: (done) ->
    {prefix, url, url_appending, health_checking_timeout} = self = @
    timeout = health_checking_timeout * 1000ms
    method = \OPTIONS
    opts = {url, method, timeout}
    INFO "#{prefix} checking healthy... (#{JSON.stringify opts})"
    (err, rsp, body) <- request opts
    if err?
      WARN err, "#{prefix} using OPTIONS to check #{url}, but failed"
      return done err, no
    else if rsp.statusCode isnt 200
      WARN "#{prefix} using OPTIONS to check #{url}, but failed with non-200 response: #{rsp.statusCode} (#{rsp.statusMessage.red})"
      return done null, no
    else
      INFO "#{prefix} using OPTIONS to check #{url} and success"
      return done null, yes

  init: (done) ->
    {url} = self = @
    return done "missing url in http-forwarder broker configs" unless url? and \string is typeof url
    return done!

  transform: (measurements) ->
    {prefix, snapshot} = self = @
    return measurements unless snapshot
    zs = measurements.length
    return measurements if zs is 0
    self.caches = {}
    for m in measurements
      [timestamp, p_type, p_id, s_type, s_id, kv] = m
      key = "#{p_type}/#{p_id}/#{s_type}/#{s_id}"
      self.caches[key] = m
    xs = [ m for key, m of self.caches ]
    INFO "#{prefix} reduce #{zs} measurements to #{xs.length} for snapshot transformation" unless xs.length is zs
    return xs

  proceed: (profile, id, measurements, context, done) ->
    {prefix, verbose, url, url_appending, compressed, request_opts, data_forwarding_timeout} = self = @
    xs = self.transform measurements
    num_of_measurements = "#{xs.length}"
    timestamp = context.timestamps.measured
    timeout = data_forwarding_timeout * 1000ms
    method = \POST
    qs = {profile, id, timestamp}
    delete qs['profile'] if url_appending
    delete qs['id'] if url_appending
    url = "#{url}/#{profile}/#{id}" if url_appending
    json = if compressed then no else yes
    c = if compressed then "json.gz" else "json"
    opts = lodash.merge {}, request_opts, {method, json, url, qs, timeout}
    pack = new DataPack profile, id, xs, context
    (pack-err, data) <- pack.get-data compressed
    return done pack-err if pack-err?
    {ratio} = pack
    # INFO "ratio: #{ratio.magenta}"
    bytes = "#{data.length}"
    if compressed
      opts['formData'] = do
        sensor_json_gz:
          value: data
          options: {filename: "/tmp/#{profile}-#{id}-#{timestamp}.json.gz", contentType: 'application/gzip'}
    else
      opts['body'] = data
      opts['headers'] = {'content-type': 'application/json'}
    (http-err, rsp, body) <- request opts
    if http-err?
      ERR http-err, "#{prefix} fails to send #{profile}/#{id}/#{timestamp} data to #{url} => (#{http-err})"
      return done http-err
    else if rsp.statusCode isnt 200
      ERR "#{prefix} fails to send #{profile}/#{id}/#{timestamp} data to #{url} because of non-200 response code: #{rsp.statusCode} (#{rsp.statusMessage})"
      return done "non-200-response"
    else
      INFO "#{prefix} forward #{profile}/#{id}/#{timestamp} - #{num_of_measurements.magenta} measurements (#{c}) successfully (#{bytes.blue} bytes)" if verbose
      return done!


module.exports = exports = HttpForwarder
