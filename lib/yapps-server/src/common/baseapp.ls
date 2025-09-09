#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[path handlebars lodash eventemitter2 debug async]>
{services} = global.ys
{DBG, ERR, WARN, INFO} = services.get_module_logger __filename
{MERGE_JSON_TEMPLATE, LOAD_PACKAGE_JSON} = HELPERS = require \../helpers/utils
debug = debug \yapps-server:common:baseapp


class AppPlugin
  (@ad, @req, @filepath, @m) ->
    throw new Error "module for plugin shall not be null" unless m?
    throw new Error "m.attach() shall not be null" unless m.attach?
    throw new Error "m.attach() shall be function but #{typeof m.attach}" unless \function is typeof m.attach
    throw new Error "m.init() shall not be null" unless m.init?
    throw new Error "m.init() shall be function but #{typeof m.init}" unless \function is typeof m.init
    {context} = ad
    {name} = m
    if name? and \string is typeof name
      @name = name
      DBG "plugin[#{@name}]: name from module.exports.name"
    else if req isnt '.' and req isnt '..' and req is path.basename req
      @name = req
      DBG "plugin[#{@name}]: name from require(name)"
    else
      try
        {p, json} = LOAD_PACKAGE_JSON ad.environment.app_dir, filepath
        {name} = json
        @name = name if name? and \string is typeof name
        @package_json = json
        DBG "plugin[#{@name}]: name from package.json"
      catch error
        @package_json = null
        @name = req
        @name = path.basename path.dirname @name if @name.endsWith "index.js"
        @name = path.basename @name
        DBG "plugin[#{@name}]: name from dirname(module.id)"
    @callee = m
    @context = context
    return

  set-callee: (@callee=null) ->
    return @

  to-json: ->
    {req, filepath, name} = self = @
    return {req, filepath, name}

  run-attach: (environment, configs, helpers, context, done) ->
    {name, callee} = self = @
    return done! unless callee?
    {attach} = callee
    c = configs[name]
    WARN "plugin[#{@name}]: missing configuration from YAML" unless c?
    c = {} unless c?
    try
      self.dependencies = attach.apply context, [name, environment, c, helpers]
    catch error
      return done error
    self.dependencies = [self.dependencies] if \string is typeof self.dependencies
    self.dependencies = [] unless self.dependencies?
    return done!

  run-init: (context, done) ->
    {name, callee, dependencies} = self = @
    return done! unless callee?
    {init} = callee
    xs = [ x for x in dependencies when not context[x]? ]
    return done new Error "#{name} depends on #{xs.join ','} but missing" if xs.length > 0
    callback = -> return done.apply null, arguments
    try
      return init.apply context, [context[name], callback]
    catch error
      return done error

  run-fini: (context, done) ->
    {name, callee} = self = @
    return done! unless callee?
    {fini} = callee
    callback = -> return done.apply null, arguments
    try
      return fini.apply context, [context[name], callback]
    catch error
      return done error



class AppContext
  (@app) ->
    {EventEmitter2} = eventemitter2
    @._server = new EventEmitter2 do
      wildcard: yes
      delimiter: \::
      newListener: no
      maxListeners: 20
    return

  set: (name, o) ->
    @[name] = o

  on: -> return @._server.on.apply @._server, arguments
  emit: -> return @._server.emit.apply @._server, arguments
  add-listener: -> return @._server.add-listener.apply @._server, arguments
  remove-listener: -> return @._server.remove-listener.apply @._server, arguments
  restart: (evt) -> return @app.restart evt


class AppDelegation
  (@app, @environment, @configs, @context) ->
    @plugins = []
    return

  init: (done) ->
    self = @
    try
      self.hook = hook = require \./require-hook
      hook.install!
    catch error
      return done error
    return done!

  create-plugin: (m) ->
    {hook} = self = @
    result = hook.lookup m
    throw new Error "no such plugin" unless result?
    {id, req, filepath} = result
    p = new AppPlugin self, req, filepath, m
    return p

  add-plugin: (p) ->
    @plugins.push p

  to-json: ->
    {plugins} = self = @
    plugins = [ (p.to-json!) for p in plugins ]
    return {plugins}

  attach-all-plugins: (done) ->
    {environment, configs, context, plugins} = self = @
    f = (p, cb) -> return p.run-attach environment, configs, HELPERS, context, cb
    return async.eachSeries plugins, f, done

  init-all-plugins: (done) ->
    {context, plugins} = self = @
    DBG "#{plugins.length} plugins to be initialized"
    g = (p, cb) ->
      try
        return p.run-init context, cb
      catch error
        return cb error
    return async.eachSeries plugins, g, done

  fini-all-plugins: (done) ->
    {context, plugins} = self = @
    DBG "#{plugins.length} plugins to be finalized"
    h = (p, cb) ->
      try
        return p.run-fini context, cb
      catch error
        return cb error
    return async.eachSeries plugins, g, done

  start: (done) ->
    {plugins} = self = @
    (attach-err) <- self.attach-all-plugins
    return done attach-err if attach-err?
    DBG "#{plugins.length} plugins are attached"
    (init-err) <- self.init-all-plugins
    return done init-err if init-err?
    DBG "#{plugins.length} plugins are initialized"
    return done!



class BaseApp
  # Constructor
  #
  # environment
  #   - app_name
  #   - process_name
  #   - app_dir
  #   - work_dir
  #   - logs_dir
  #   - startup_time
  #
  # templated_configs
  #   - load from YAML config file, and merged with command-line options after `--` (support nested json object with dot notation)
  #   - default values are loaded from yapps-server/src/common/defaults.ls
  #   - those handlebar variables (e.g. `{{work_dir}}`) are still kept
  #   - the section `logger` is not in the templated_configs
  #
  #
  (@environment, @templated_configs) ->
    @context = new AppContext @
    @delegation = null
    return

  init-internally: (environment, configs, done) ->
    return done!

  init: (done) ->
    {environment, templated_configs, context} = self = @
    try
      self.configs = configs = MERGE_JSON_TEMPLATE templated_configs, environment
    catch error
      return done error
    d = self.delegation = new AppDelegation self, environment, configs, context
    (err) <- d.init
    return done err if err?
    return self.init-internally environment, configs, done


module.exports = exports = {BaseApp, AppContext, AppPlugin}
