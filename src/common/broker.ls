#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[async lodash]>
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename


class Broker
  (@parent, @environment, @helpers, configs) ->
    @defaults = {} unless @defaults?
    @configs = lodash.merge {}, @defaults, configs
    {prefix} = parent
    @prefix = prefix
    # INFO "#{prefix} environment => #{helpers.PRETTIZE_KVS @environment}"
    INFO "#{prefix} configs => #{helpers.PRETTIZE_KVS @configs}"
    @verbose = @configs['verbose']
    return

  init: (done) ->
    return done!

  check-health: (done) ->
    return done null, yes

  proceed: (profile, id, measurements, context, done) ->
    return done!

module.exports = exports = {Broker}