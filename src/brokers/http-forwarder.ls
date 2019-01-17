#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[path zlib]> # builtin
require! <[async lodash request]>
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename
{constants} = require \../common/definitions
{APPEVT_TIME_SERIES_V1_DATA_POINTS, APPEVT_TIME_SERIES_V3_MEASUREMENTS} = constants

const FORWARDER_DEFAULT_OPTIONS =
  name: 'unknown'
  enabled: no
  url: null
  compressed: no
  health_check: no
  url_append: no
  matched_profiles: '.*'
  matched_ids: '.*'
  request_opts: {}

const DEFAULT_HEALTH_CHECK_PERIOD = 60s


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


class Forwarder
  (@manager, @opts, @verbose) ->
    {name, url, compressed, health_check, matched_profiles, matched_ids} = @opts = lodash.merge {}, FORWARDER_DEFAULT_OPTIONS, opts
    @name = name
    @prefix = "forwarders[#{name.cyan}]"
    @url = url
    @compressed = compressed
    @compressed = no unless @compressed? and \boolean is typeof @compressed
    @health-check = health_check
    @health-check = no unless @health-check? and \boolean is typeof @health-check
    @health-check-timeout = DEFAULT_HEALTH_CHECK_PERIOD
    @health-checking = no
    @healthy = if @health-check then no else yes
    matched_profiles = '.*' unless matched_profiles? and \string is typeof matched_profiles
    matched_profiles = '.*' if matched_profiles is \*
    matched_ids = '.*' unless matched_ids? and \string is typeof matched_ids
    matched_ids = '.*' if matched_ids is \*
    @profile-matcher = if matched_profiles is \.* then null else new RegExp matched_profiles
    @id-matcher = if matched_ids is \.* then null else new RegExp matched_ids
    return

  init: (done) ->
    {prefix, url} = self = @
    return done "missing url in options" unless url?
    return done "expects url as `string` but #{typeof url}" unless \string is typeof url
    INFO "#{prefix}: initialized. (url: #{url.magenta})"
    f = -> return self.at-check!
    self.timer = setInterval f, 1000ms
    self.health-check-timeout = 0
    self.at-health-check!
    return done!

  at-health-check: ->
    {prefix, url, health-check, health-check-timeout, healthy, health-checking} = self = @
    return unless health-check
    return if health-checking
    self.health-check-timeout = health-check-timeout - 1
    return if health-check-timeout > 0
    timeout = DEFAULT_HEALTH_CHECK_PERIOD .>>. 1
    timeout = 10 if timeout < 10
    timeout = timeout * 1000ms
    method = \OPTIONS
    opts = {url, method, timeout}
    INFO "#{prefix}: checking healthy... (#{JSON.stringify opts})"
    self.health-checking = yes
    (err, rsp, body) <- request opts
    self.health-checking = no
    self.health-check-timeout = DEFAULT_HEALTH_CHECK_PERIOD
    return WARN "#{prefix}: using OPTIONS to check #{url}, but failed: #{err}" if err?
    return WARN "#{prefix}: using OPTIONS to check #{url}, but failed with non-200 response: #{rsp.statusCode} (#{rsp.statusMessage.red})" unless rsp.statusCode is 200
    self.healthy = yes
    return INFO "#{prefix}: using OPTIONS to check #{url} and success"

  at-check: ->
    @.at-health-check!
    return

  forward: (pack, done) ->
    {prefix, compressed, url, opts, verbose, healthy, profile-matcher, id-matcher} = self = @
    {profile, id, measurements, context} = pack
    # INFO "testing #{profile}, #{profile-matcher.test profile}" if profile-matcher?
    # INFO "testing #{id}, #{id-matcher.test id}" if id-matcher?
    return DBG "#{prefix}: drop #{profile}/#{id} because of profile mismatch" if profile-matcher? and (not profile-matcher.test profile)
    return DBG "#{prefix}: drop #{profile}/#{id} because of id mismatch" if id-matcher? and not id-matcher.test id
    timestamp = context.timestamps.measured
    if not healthy
      INFO "#{prefix}: #{url.gray} is not healthy to forward #{profile}/#{id}/#{timestamp}"
      return done!
    num_of_measurements = "#{measurements.length}"
    method = \POST
    qs = {profile, id, timestamp}
    delete qs['profile'] if opts.url_append
    delete qs['id'] if opts.url_append
    url = "#{url}/#{profile}/#{id}" if opts.url_append
    json = if compressed then no else yes
    c = if compressed then "json.gz" else "json"
    opts = lodash.merge {}, opts.request_opts, {method, json, url, qs}
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
    return self.at-forward-ng done, "failed to send #{profile}/#{id}/#{timestamp} data to #{url} => #{http-err}" if http-err?
    return self.at-forward-ng done, "failed to send #{profile}/#{id}/#{timestamp} data to #{url} because of non-200 response code: #{rsp.statusCode} (#{rsp.statusMessage})" unless rsp.statusCode is 200
    INFO "#{prefix}: #{profile}/#{id}/#{timestamp}: forward #{num_of_measurements.magenta} measurements (#{c}) successfully (#{bytes.blue} bytes)" if verbose
    return self.at-forward-ok done

  at-forward-ng: (callback, err) ->
    {health-check} = self = @
    return callback err unless health-check
    self.healthy = no
    self.health-check-timeout = DEFAULT_HEALTH_CHECK_PERIOD
    return callback err

  at-forward-ok: (callback) ->
    self = @
    self.healthy = yes
    self.health-check-timeout = DEFAULT_HEALTH_CHECK_PERIOD
    return callback!


class ForwardManager
  (@environment, @configs, @helpers, @app) ->
    self = @
    self.verbose = configs.verbose
    self.verbose = no unless \boolean is typeof self.verbose
    self.forwarders = [ (new Forwarder self, d, self.verbose) for d in configs.destinations when d.enabled? and d.enabled ]
    return

  init: (done) ->
    {app, forwarders} = self = @
    app.on APPEVT_TIME_SERIES_V3_MEASUREMENTS, -> self.at-ts-v3-measurements.apply self, arguments
    iterator = (f, cb) -> return f.init cb
    return async.eachSeries forwarders, iterator, done

  at-ts-v3-measurements: (profile, id, measurements, context) ->
    {forwarders} = self = @
    pack = new DataPack profile, id, measurements, context
    for f in forwarders
      (err) <- f.forward pack
      ERR err, "forwarding failure" if err?
    return



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

