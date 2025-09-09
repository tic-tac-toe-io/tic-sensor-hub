#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#

# ---- WORKER ----
#
require! <[path]>
require! <[async]>

{services} = global.ys
{DBG, ERR, WARN, INFO} = services.get_module_logger __filename

{COLORIZED, PRETTIZE_KVS, PRINT_PRETTY_JSON, MERGE_JSON_TEMPLATE} = require \../helpers/utils
{BaseApp} = require \../common/baseapp
{create_message, message_states, message_types} = require \../common/message
{STATE_BOOTSTRAPPING, STATE_BOOTSTRAPPED, STATE_READY, STATE_RUNNING} = message_states
{TYPE_RUNNING_WEB_CONNECTION_DISPATCH} = message_types


class WebWrapper
  (@worker) ->
    return

  start: ->
    {worker} = self = @
    {delegation} = worker
    (start-err) <- delegation.start
    return worker.at-start-failed start-err if start-err?
    {context} = worker
    web = self.web = context['web']
    (serve-err) <- web.serve
    return worker.at-start-failed serve-err if serve-err?
    return worker.at-start-successful!

  at-incoming-connection: (c) ->
    {web} = self = @
    return web.at-master-incoming-connection c



class WorkerApp extends BaseApp
  (@environment, @templated_configs, @master_settings) ->
    super environment, templated_configs
    @ready = no

  init-internally: (environment, configs, done) ->
    {master_settings, delegation, context} = self = @
    INFO "init-internally: configs => #{JSON.stringify configs}"
    f = (opts, cb) ->
      try
        {name, req, filepath} = opts
        INFO "loading module #{name.yellow} from #{filepath.green} (origin: #{req.gray})"
        m = require filepath
        p = delegation.create-plugin m
        delegation.add-plugin p
        return cb!
      catch error
        return cb error
    (init-plugin-err) <- async.eachSeries master_settings['plugins'], f
    return done init-plugin-err if init-plugin-err?
    ww = self.ww = new WebWrapper self
    done null, ww
    return process.send create_message STATE_BOOTSTRAPPED

  at-message: (message, connection) ->
    self = @
    {state, type, payload} = message
    return unless state is STATE_RUNNING
    return self.at-web-incoming-connection payload, connection if type is TYPE_RUNNING_WEB_CONNECTION_DISPATCH

  at-web-incoming-connection: (payload, connection) ->
    return @ww.at-incoming-connection connection

  at-start-successful: ->
    INFO "READY".cyan
    @ready = yes
    return process.send create_message STATE_READY

  at-start-failed: (err) ->
    ERR err, "failed to start"
    return process.exit 1

module.exports = exports = WorkerApp