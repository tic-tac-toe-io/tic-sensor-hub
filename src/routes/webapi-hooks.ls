#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[path zlib express]>
moment = require \moment-timezone
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename
{constants} = require \../common/definitions
{APPEVT_TIME_SERIES_V3_MEASUREMENTS} = constants


NG = (message, code, status-code, req, res) ->
  url = req.originalUrl
  result = {url, code, message}
  return res.status status-code .json result


module.exports = exports =
  name: \webapi-hooks

  attach: (name, environment, configs, helpers) ->
    return <[web]>

  init: (p, done) ->
    {web} = app = @
    {REST_ERR, REST_DAT, UPLOAD} = web.get_rest_helpers!
    hook = new express!
    hook.post '/http-forwarder/:profile/:id', (UPLOAD.single \sensor_json_gz), (req, res) ->
      {file, params, query} = req
      {profile, id} = params
      {timestamp} = query
      return NG "invalid file upload form", -1, 400, req, res unless file?
      {fieldname, originalname, size, buffer, mimetype} = file
      return NG "missing sensor_json_gz field", -1, 400, req, res unless fieldname == \sensor_json_gz
      return PROCESS_EMPTY_DATA id, profile, originalname, req, res if size is 0
      file.buffer = null
      filename = originalname
      bytes = buffer.length
      res.status 200 .json { code: 0, message: null, result: {profile, id, filename, bytes} }

      (err, raw) <- zlib.gunzip buffer
      return NG "failed to decompress: #{err}", -1, 200, req, res if err?
      text = raw.toString!
      try
        data = JSON.parse text
      catch error
        return NG "failed to parse json text: #{error}", -2, 200, req, res
      {measurements, context} = data
      INFO "#{req.path.yellow}: #{filename} (#{bytes} bytes) decompressed to #{raw.length} bytes, with #{measurements.length} measurements"
      return app.emit APPEVT_TIME_SERIES_V3_MEASUREMENTS, profile, id, measurements, context

    web.use-api \hook, hook
    return done!

  fini: (p, done) ->
    return done!
