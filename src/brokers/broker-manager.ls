#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[path]> # builtin
require! <[async lodash]>
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename
{constants} = require \../common/definitions
{APPEVT_TIME_SERIES_V3_MEASUREMENTS} = constants


const DEFAULT_BROKER_OPTIONS =
  type: null
  enabled: no
  verbose: no
  behaviors:
    health_check: no
    health_check_period: 60s
    queue_if_unavailable: no
  filter:
    matched_profiles: \*
    matched_ids: \*
    matched_peripheral_types: \*
    matched_sensor_types: \*
  broker: {}


LOAD_BROKER_CLASS = (type, done) ->
  clazz = null
  try
    clazz = require \./filesystem if type is \file
    clazz = require \./http-forwarder if type is \http
    clazz = require \./ifdb-1x-writer if type is \ifdb
  catch error
    return done error
  return done null, clazz if clazz?
  return done "unsupported class: #{type}"



class DataFilter
  (@parent, @opts) ->
    {PRETTIZE_KVS} = parent.manager.helpers
    {prefix} = parent
    self = @
    self.prefix = prefix
    INFO "#{prefix} filter => #{PRETTIZE_KVS opts}"
    [ (self.update-filter-opts name) for name in <[profile id peripheral_type sensor_type]> ]
    return

  update-filter-opts: (name) ->
    {opts, prefix} = self = @
    v = opts["matched_#{name}s"]
    INFO "#{prefix} #{name} => v => #{v}"
    v = if v? then v else '.*'
    v = '.*' if v is '*'
    r = new RegExp v
    m = "#{name}_matcher"
    self[m] = null
    return if v is \.*
    self[m] = new RegExp v
    return INFO "#{prefix} applying filter #{v.yellow} for #{name.green}"

  check-profile: (profile, id) ->
    {profile_matcher, prefix} = @
    return yes unless profile_matcher?
    return yes if profile_matcher.test profile
    INFO "#{prefix} drop #{profile}/#{id} because of profile mismatch"
    return no

  check-id: (profile, id) ->
    {id_matcher, prefix} = @
    return yes unless id_matcher?
    return yes if id_matcher.test id
    INFO "#{prefix} drop #{profile}/#{id} because of id mismatch"
    return no

  check-measurement: (m) ->
    {peripheral_type_matcher, sensor_type_matcher, prefix} = @
    [timestamp, p-type, p-id, s-type, s-id, vs] = m
    p-matched = yes
    p-matched = peripheral_type_matcher.test p-type if peripheral_type_matcher?
    return no unless p-matched
    s-matched = yes
    s-matched = sensor_type_matcher.test s-type if sensor_type_matcher?
    return no unless s-matched
    return yes

  filter: (profile, id, measurements, context) ->
    {prefix} = self = @
    DBG "#{prefix} filter #{profile}/#{id} => #{measurements.length} measurements"
    return [] unless self.check-profile profile, id
    return [] unless self.check-id profile, id
    xs = [ m for m in measurements when self.check-measurement m ]
    return xs
    # a = measurements.length
    # b = xs.length
    # ys = measurements.length - xs.length
    # INFO "#{prefix} partially drop #{profile}/#{id} measurements, from #{a} to #{b}." unless ys is 0
    # return xs


class DecoratedBroker
  (@manager, @name, @type, configs) ->
    self = @
    self.broker = null
    self.prefix = "brokers.#{type}[#{name.cyan}]"
    self.configs = c = lodash.merge {}, DEFAULT_BROKER_OPTIONS, configs
    {health_check, health_check_period, queue_if_unavailable} = c['behaviors']
    self.health_check = health_check
    self.health_check_period = self.health_check_timeout = health_check_period
    self.healthy = no
    self.checking_health = no
    self.queue_if_unavailable = queue_if_unavailable
    self.proceeding = no
    self.df = new DataFilter self, c['filter']
    return

  init: (done) ->
    {type, prefix, configs, manager, health_check} = self = @
    {environment, helpers} = manager
    (load-err, clazz) <- LOAD_BROKER_CLASS type
    return done load-err if load-err?
    self.broker = broker = new clazz self, environment, helpers, configs['broker']
    (init-err) <- broker.init
    return done init-err if init-err?
    INFO "#{prefix} init successfully (behaviors: #{helpers.PRETTIZE_KVS configs.behaviors})"
    return done! unless health_check
    (check-err, healthy) <- broker.check-health
    ERR check-err, "#{prefix} fails to check health" if check-err?
    INFO "#{prefix} check health and get #{healthy}"
    self.healthy = healthy is yes
    return done!

  at-health-check: ->
    {broker, prefix, healthy, health_check_timeout, health_check_period, checking_health} = self = @
    return if healthy
    return if checking_health
    self.health_check_timeout = health_check_timeout - 1
    return if self.health_check_timeout > 0
    self.checking_health = yes
    (err, healthy) <- broker.check-health
    self.checking_health = no
    self.healthy = healthy is yes
    self.health_check_timeout = health_check_period
    # return WARN err, "#{prefix} fails to check health, err => #{err}"

  at-check: ->
    @.at-health-check!
    return

  at-data: (profile, id, measurements, context) ->
    {prefix, df, broker, proceeding, health_check, healthy} = self = @
    return WARN "#{prefix} drop #{profile}/#{id} #{measurements.length} measurements because of busy. TODO: implement job queue" if proceeding
    return WARN "#{prefix} drop #{profile}/#{id} #{measurements.length} measurements because of not healthy. TODO: implement job queue" if health_check and not healthy
    return if proceeding # [todo] Needs to implement queue, also implement health check.
    xs = df.filter profile, id, measurements, context
    return INFO "#{prefix} drop #{profile}/#{id} #{measurements.length} measurements because of mismatch" if xs.length is 0
    comments = if xs.length is measurements.length then "" else "(reduced from #{measurements.length})"
    INFO "#{prefix} proceeds #{xs.length} measurements #{comments}"
    self.proceeding = yes
    (err) <- broker.proceed profile, id, xs, context
    self.proceeding = no
    return unless err?
    ERR err, "#{profile}: failed to process #{profile}/#{id}, #{xs.length} records" if err? # [todo] Need queue to cache these failed-delivery
    self.healthy = no
    self.health_check_timeout = self.health_check_period


class BrokerManager
  (@environment, @configs, @helpers, @app) ->
    self = @
    self.verbose = configs.verbose
    self.verbose = no unless \boolean is typeof self.verbose
    self.brokers = brokers = [ (new DecoratedBroker self, name, opts.type, opts) for name, opts of configs.destinations when opts.type? and opts.enabled? and opts.enabled ]
    self.broker-map = { [b.name, b] for b in brokers }
    f = -> return self.at-check!
    self.timer = setInterval f, 1000ms
    return

  init: (done) ->
    {app, brokers} = self = @
    app.on APPEVT_TIME_SERIES_V3_MEASUREMENTS, -> self.at-ts-v3-measurements.apply self, arguments
    iterator = (f, cb) -> return f.init cb
    return async.eachSeries brokers, iterator, done

  fini: (done) ->
    clearInterval @timer
    return done!

  at-ts-v3-measurements: (profile, id, measurements, context) ->
    {brokers} = self = @
    [ (b.at-data profile, id, measurements, context) for b in brokers ]

  at-check: ->
    {brokers} = self = @
    [ (b.at-check!) for b in brokers ]



module.exports = exports =
  name: \broker-manager

  attach: (name, environment, configs, helpers) ->
    app = @
    broker = app[name] = new BrokerManager environment, configs, helpers, app
    return null

  init: (p, done) ->
    return p.init done

  fini: (p, done) ->
    return p.fini done

