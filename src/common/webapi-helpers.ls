#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#

NG = (message, code, status-code, req, res) ->
  url = req.originalUrl
  result = {url, code, message}
  return res.status status-code .json result

funcs = {NG}

module.exports = exports = {funcs}