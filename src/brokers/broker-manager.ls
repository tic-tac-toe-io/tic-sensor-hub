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
  behaviors:
    health_check: no
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
    clazz = require \./filesystem if type is \filesystem
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
    INFO "#{prefix} filter #{profile}/#{id} => #{measurements.length} measurements"
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
    {health_check, queue_if_unavailable} = c['behaviors']
    self.health_check = health_check
    self.queue_if_unavailable = queue_if_unavailable
    self.proceeding = no
    self.df = new DataFilter self, c['filter']
    return

  init: (done) ->
    {type, prefix, configs, manager} = self = @
    {environment, helpers} = manager
    (load-err, clazz) <- LOAD_BROKER_CLASS type
    return done load-err if load-err?
    self.broker = broker = new clazz self, environment, helpers, configs['broker']
    (init-err) <- broker.init
    return done init-err if init-err?
    INFO "#{prefix} init successfully."
    return done!

  at-data: (profile, id, measurements, context) ->
    {prefix, df, broker, proceeding} = self = @
    return if proceeding # [todo] Needs to implement queue, also implement health check.
    xs = df.filter profile, id, measurements, context
    return INFO "#{prefix} drop #{profile}/#{id} #{measurements.length} measurements because of mismatch" if xs.length is 0
    INFO "#{prefix} proceeds #{xs.length} measurements (reduced from #{measurements.length})"
    (err) <- broker.proceed profile, id, xs, context
    return ERR err, "#{profile}: failed to process #{profile}/#{id}, #{measurements.length} records" if err? # [todo] Need queue to cache these failed-delivery


class BrokerManager
  (@environment, @configs, @helpers, @app) ->
    self = @
    self.verbose = configs.verbose
    self.verbose = no unless \boolean is typeof self.verbose
    self.brokers = brokers = [ (new DecoratedBroker self, name, opts.type, opts) for name, opts of configs.destinations when opts.type? and opts.enabled? and opts.enabled ]
    self.broker-map = { [b.name, b] for b in brokers }
    return

  init: (done) ->
    {app, brokers} = self = @
    app.on APPEVT_TIME_SERIES_V3_MEASUREMENTS, -> self.at-ts-v3-measurements.apply self, arguments
    iterator = (f, cb) -> return f.init cb
    return async.eachSeries brokers, iterator, done

  at-ts-v3-measurements: (profile, id, measurements, context) ->
    {brokers} = self = @
    # INFO "at-ts-v3-measurements: #{profile}/#{id} => #{measurements.length} measurements"
    [ (b.at-data profile, id, measurements, context) for b in brokers ]


module.exports = exports =
  name: \broker-manager

  attach: (name, environment, configs, helpers) ->
    app = @
    broker = app[name] = new BrokerManager environment, configs, helpers, app
    return null

  init: (p, done) ->
    return p.init done

  fini: (p, done) ->
    return done!

