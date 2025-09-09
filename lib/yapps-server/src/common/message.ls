#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
const STATE_BOOTSTRAPPING = \bootstrapping
const STATE_BOOTSTRAPPED = \bootstrapped
const STATE_READY = \ready
const STATE_RUNNING = \running

const TYPE_NONE = \none
const TYPE_BOOTSTRAP_REQUEST_CONFIGS = \req-worker-configs
const TYPE_BOOTSTRAP_RESPONSE_CONFIGS = \rsp-worker-configs

const TYPE_RUNNING_WEB_CONNECTION_DISPATCH = \web-tcp-dispatch


const message_states = {
  STATE_BOOTSTRAPPING,
  STATE_BOOTSTRAPPED,
  STATE_READY,
  STATE_RUNNING
}

const message_types = {
  TYPE_NONE,
  TYPE_BOOTSTRAP_REQUEST_CONFIGS,
  TYPE_BOOTSTRAP_RESPONSE_CONFIGS,
  TYPE_RUNNING_WEB_CONNECTION_DISPATCH
}

create_message = (state, type=TYPE_NONE, payload={}) ->
  return {state, type, payload}


module.exports = exports = {create_message, message_states, message_types}
