#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[path zlib express lodash request crypto]>
require! <[passport]>
{BasicStrategy} = require \passport-http
moment = require \moment-timezone
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename
{constants} = require \../common/definitions
{APPEVT_TIME_SERIES_V3_MEASUREMENTS, WEBAPI_UPLOAD_ARCHIVE_MULTIPART_FIELD} = constants
{funcs} = require \../common/webapi-helpers
{NG} = funcs
PARSER = require \../parsers/toe3-json7


DEFAULT_SETTINGS =
  enabled: no
  timezone: \Asia/Taipei
  misc:
    dm:
      server: \https://tic-dm.t2t.io
      user: \misc
      pass: \misc


HANDLE_EMPTY_FILE = (profile, id, originalname, req, res) ->
  # Sometimes, the client might upload a sensor archive file with
  # zero bytes, because of possible disk failure. We need to accept
  # such improper request, and return HTTP/200 OKAY to client.
  #
  # If we responses HTTP/400 error to client, client will retry to
  # upload same corrupted sensor archive file (zero bytes) again and
  # again. That's why we responses HTTP/200 OKAY for such case.
  #
  message = "#{id}/#{profile}/#{originalname} but unexpected zero bytes"
  WARN message
  return NG message, -4, 200, req, res


HANDLE_INVALID_ARCHIVE = (profile, id, originalname, err, req, res) ->
  # Although the uploaded archive is not a valid gzip file,
  # we still need to accept it. Otherwise, the client will keep uploading
  # the corrupted archive file onto sensor-hub.
  #
  message = "#{profile}/#{id}/#{originalname} decompression failure."
  ERR err, message
  return NG message, -2, 200, req, res


HANDLE_INVALID_JSON_FORMAT = (profile, id, originalname, err, req, res) ->
  # # Although the uploaded archive is not a valid json file,
  # we still need to accept it. Otherwise, the client will keep uploading
  # the corrupted archive file onto sensor-hub.
  #
  message = "#{profile}/#{id}/#{originalname} is invalid JSON data"
  ERR error, message
  return NG message, -3, 200, req, res


HANDLE_INVALID_DATA_FORMAT = (profile, id, originalname, err, req, res) ->
  # Although the uploaded archive is not a valid DG3 data,
  # we still need to accept it. Otherwise, the client will keep uploading
  # the corrupted archive file onto sensor-hub.
  #
  message = "#{profile}/#{id}/#{originalname} is invalid DG3 data"
  ERR error, message
  return NG message, -3, 200, req, res




module.exports = exports =
  name: \webapi-upload

  attach: (name, environment, configs, helpers) ->
    module.configs = lodash.merge {}, DEFAULT_SETTINGS, configs
    module.helpers = helpers
    return <[web]>

  init: (p, done) ->
    {configs, helpers} = module
    {enabled} = configs
    if not enabled
      WARN "disabled!!"
      return done!
    {web} = app = @
    {REST_ERR, REST_DAT, UPLOAD} = web.get_rest_helpers!
    {PRETTIZE_KVS} = helpers

    up = new express!
    ua = new express!

    strategy = new BasicStrategy (userid, password, done) ->
      INFO "basic-auth: user: #{userid.yellow}, password: #{password.green}"
      [client, profile, id] = userid.split '/'
      return done "missing client" unless client?
      return done "missing profile" unless profile?
      return done "missing id" unless id?
      return done null, {userid, profile, id, client} unless profile is \player
      {dm} = configs.misc
      {server, user, pass} = dm
      # INFO "auth: dms => #{PRETTIZE_KVS dm}"
      url = "#{server}/api/v3/nodes/#{profile}/find/identity/match/#{id}"
      auth = {user, pass}
      opts = {url, auth}
      (err, rsp, body) <- request.get opts
      if err?
        ERR err, "#{url} => failed to search node by given identity"
        return done "failed to search node by given identity #{id}, #{err}"
      else if rsp.statusCode isnt 200
        ERR "#{url} => failed to search node with identity, non-200 response: #{rsp.statusCode}"
        return done "failed to search node with identity, non-200 response: #{rsp.statusCode}"
      else
        json = JSON.parse body
        {identity, token, serial_number} = json.data[0]
        hash = ((crypto.createHmac 'sha256', token).update serial_number .digest 'hex').to-upper-case!
        id = identity
        INFO "id: #{id}, token: #{token.yellow}, hash: #{hash.red}"
        return done null, {userid, profile, id, client} if password.length is 16 and password is hash.substring 0, 16
        return done null, {userid, profile, id, client} if password.length is 32 and password is hash.substring 0, 32
        return done "hash mismatched: #{hash}, #{password}"

    passport.use strategy


    up.post '/:profile/:id/:p_type/:p_id/:s_type/:s_id', (passport.authenticate \basic, {session: no}), (req, res) ->
      received = now = Date.now!
      {params, query, ip, body} = req
      {profile, id, p_type, p_id, s_type, s_id} = params
      {epoch} = query
      epoch = received unless epoch?
      epoch = parseInt epoch if \string is typeof epoch
      measured = epoch
      m = [epoch, p_type, p_id, s_type, s_id, body]
      measurements = [m]
      compressed-size = raw-size = (JSON.stringify measurements).length
      filename = \unknown
      transformed = Date.now!
      delta = now - epoch
      prefix = "/api/v3/upload: #{profile.cyan}/#{id.yellow}/#{p_type}/#{p_id}/#{s_type}/#{s_id} =>"
      res.status 200 .json { code: 0, message: null, result: {}, configs: {} }
      INFO "#{prefix} #{PRETTIZE_KVS body}"
      return app.emit APPEVT_TIME_SERIES_V3_MEASUREMENTS, profile, id, measurements, do
        source: \standard-upload-lv4
        upload: {filename, compressed-size, raw-size}
        timestamps: {measured, received, transformed, delta}


    up.post '/:profile/:id', (UPLOAD.single WEBAPI_UPLOAD_ARCHIVE_MULTIPART_FIELD), (req, res) ->
      {file, params, query, ip} = req
      {timezone, uptime, epoch, boots} = query
      {profile, id} = params
      return NG "invalid file upload form", -1, 400, req, res unless file?
      {fieldname, originalname, size, buffer} = file
      return NG "missing #{WEBAPI_UPLOAD_ARCHIVE_MULTIPART_FIELD} field", -1, 400, req, res unless fieldname is WEBAPI_UPLOAD_ARCHIVE_MULTIPART_FIELD
      now = (new Date!) - 0
      boots = parse-int boots
      boots = 0 if boots is NaN
      uptime = parse-int uptime
      uptime = 0 if uptime is NaN
      epoch = parse-int epoch
      epoch = 0 if epoch is NaN
      global-anchor = {boots, uptime, epoch, now}
      timezone = module.configs.timezone unless timezone?
      size-text = "#{size}"
      prefix = "/api/v3/upload: #{profile.cyan}/#{id.yellow}[#{originalname.green}] =>"
      INFO "#{prefix} #{timezone}, #{boots}/#{uptime}/#{epoch}, #{size-text.magenta} bytes"
      return HANDLE_EMPTY_FILE profile, id, originalname, req, res if size is 0
      (zerr, raw) <- zlib.gunzip buffer
      return HANDLE_INVALID_ARCHIVE profile, id, originalname, zerr, req, res if zerr?
      raw-size = raw.length
      text = raw.toString!
      INFO "#{prefix} decompress to #{raw-size.toString!.magenta} bytes"
      try
        json = JSON.parse text
      catch error
        return HANDLE_INVALID_JSON_FORMAT profile, id, originalname, error, req, res
      try
        parser = new PARSER {}
        parser.parse json, global-anchor
        measurements = parser.to-ttt yes
        parser = null
      catch error
        return HANDLE_INVALID_DATA_FORMAT profile, id, originalname, error, req, res
      res.status 200 .json { code: 0, message: null, result: {}, configs: {} }
      received = now
      transformed = (new Date!).valueOf!
      num_of_points = json.data.points.length
      num_of_measurements = measurements.length
      return INFO "#{prefix} ignore because of no measurements" if num_of_measurements is 0
      measured = measurements[0][0]
      delta = now - epoch
      filename = originalname
      compressed-size = size
      # metadata = {size, raw-size, delta, ip, num_of_measurements, num_of_points}
      # context = {timezone, uptime, epoch, boots, timestamps}
      return app.emit APPEVT_TIME_SERIES_V3_MEASUREMENTS, profile, id, measurements, do
        source: \toe3-upload-alpha
        upload: {filename, compressed-size, raw-size}
        timestamps: {measured, received, transformed, delta}


    ua.post '/:profile/:id/:type', (UPLOAD.single \archive), (req, res) ->
      {query, headers, ip, params, file} = req
      # INFO "query => #{JSON.stringify query}"
      # INFO "headers => #{JSON.stringify headers}"
      # INFO "params => #{JSON.stringify params}"
      boots = query['_boots']
      uptime = query['_uptime']
      epoch = query['_epoch']
      timezone = headers['x-toe-timezone']
      toe-app = headers['x-toe-app']
      toe-app-version = headers['x-toe-app-version']
      {profile, id, type} = params
      return NG "invalid file upload form", -1, 400, req, res unless file?
      {fieldname, originalname, size, buffer} = file
      return NG "missing archive field in http form", -1, 400, req, res unless fieldname is \archive
      now = (new Date!).valueOf!
      boots = parse-int boots
      boots = 0 if boots is NaN
      uptime = parse-int uptime
      uptime = 0 if uptime is NaN
      epoch = parse-int epoch
      epoch = 0 if epoch is NaN
      global-anchor = {boots, uptime, epoch, now}
      timezone = "Asia/Taipei" unless timezone?
      size-text = "#{size}"
      prefix = "/api/v3/upload-archive: #{profile.cyan}/#{id.yellow}/#{type.gray}[#{originalname.green}] =>"
      INFO "#{prefix} #{timezone}, #{boots}/#{uptime}/#{epoch}, #{size-text.magenta} bytes"
      return HANDLE_EMPTY_FILE profile, id, originalname, req, res if size is 0
      (zerr, raw) <- zlib.gunzip buffer
      return HANDLE_INVALID_ARCHIVE profile, id, originalname, zerr, req, res if zerr?
      raw-size = raw.length
      x = "#{raw-size}"
      text = raw.toString!
      INFO "#{prefix} decompress to #{x.magenta} bytes"
      try
        json = JSON.parse text
      catch error
        return HANDLE_INVALID_JSON_FORMAT profile, id, originalname, error, req, res
      try
        parser = new PARSER {}
        parser.parse json, global-anchor
        measurements = parser.to-ttt yes
        parser = null
      catch error
        return HANDLE_INVALID_DATA_FORMAT profile, id, originalname, error, req, res
      res.status 200 .json { code: 0, message: null, result: {}, configs: {} }
      received = now
      transformed = (new Date!).valueOf!
      num_of_points = json.data.points.length
      num_of_measurements = measurements.length
      return INFO "#{prefix} ignore because of no measurements" if num_of_measurements is 0
      measured = measurements[0][0]
      delta = now - epoch
      filename = originalname
      compressed-size = size
      return app.emit APPEVT_TIME_SERIES_V3_MEASUREMENTS, profile, id, measurements, do
        source: \toe3-upload
        upload: {filename, compressed-size, raw-size}
        timestamps: {measured, received, transformed, delta}


    web.use-api \upload, up           # for early-version of TOE3
    web.use-api \upload-archive, ua   # official api endpoint to receive time-series sensor data archive
    return done!

  fini: (p, done) ->
    return done!
