#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[debug async]>
debug = debug \yapps-server:worker:loader

{create_message, message_states, message_types} = require \../common/message
{STATE_BOOTSTRAPPING, STATE_READY} = message_states
{TYPE_BOOTSTRAP_REQUEST_CONFIGS, TYPE_BOOTSTRAP_RESPONSE_CONFIGS} = message_types


class WorkerLoader
  (@opts={}) ->
    self = @
    self.ready = no
    self.index = null
    self.app = null
    process.on \message, (message, connection) -> return self.at-message message, connection

  init: (done) ->
    self = @
    self.init-callback = done
    debug "init-callback: %o", typeof done
    process.send create_message STATE_BOOTSTRAPPING, TYPE_BOOTSTRAP_REQUEST_CONFIGS
    return

  at-message: (message, connection) ->
    {index, app, ready} = self = @
    debug "got-a-message: %o", message
    return app.at-message message, connection if app? and app.ready
    {state, type, payload} = message
    return self.at-bootstrapping-message type, payload if state is STATE_BOOTSTRAPPING

  at-bootstrapping-message: (type, payload) ->
    return @.at-bootstrapping-rsp-conf payload if type is TYPE_BOOTSTRAP_RESPONSE_CONFIGS

  at-bootstrapping-rsp-conf: (payload) ->
    {init-callback} = self = @
    {index, environment, templated_configs, master_settings} = payload
    self.index = index
    self.environment = environment
    debug "index: %o", index
    debug "environment: %o", environment
    debug "templated_configs: %o", templated_configs
    debug "master_settings: %o", master_settings
    logger = require \../common/logger
    (logger-err, get-module-logger) <- logger.init index, environment, templated_configs['logger'], {}, {}
    return init-callback logger-err if logger-err?
    {services} = global.ys
    services.get_module_logger = get-module-logger
    WorkerApp = require \./app
    app = self.app = new WorkerApp environment, templated_configs, master_settings
    (init-err, web) <- app.init
    return init-callback init-err if init-err?
    logger = get-module-logger process.argv[1]
    return init-callback null, logger, null, web




# ---- WORKER ----
#
module.exports = exports = (opts, done) ->
  {loader} = module
  return done "disallow to create duplicated instance of yapps-server(worker)" if loader?
  # Simply ignore all options, and wait for master process to deliver all options.
  loader = module.loader = new WorkerLoader {}
  debug "done: %o", typeof done
  return loader.init done
