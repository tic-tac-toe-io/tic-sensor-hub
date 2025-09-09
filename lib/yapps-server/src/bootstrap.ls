#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[cluster debug]>
debug = debug \yapps-server:bootstrap

DELEGATE_EXPORT = (m) ->
  try
    debug "bootstrapping #{m} from #{__dirname}"
    bootstrap = require m
    module.exports = exports = {bootstrap}
    debug "successfully load #{m}"
  catch
    console.error "failed to load #{m.red} from #{__dirname.yellow} due to error: #{e}"
    throw e


BOOTSTRAP = (m) ->
  #
  # Initialize the context of yapps-server, including 1 field: services
  services = {}
  global.ys = {services}
  #
  # Use `loader` module to load App for master process and worker process(es)
  return DELEGATE_EXPORT m


return BOOTSTRAP "./master/loader" if cluster.isMaster
return BOOTSTRAP "./worker/loader"