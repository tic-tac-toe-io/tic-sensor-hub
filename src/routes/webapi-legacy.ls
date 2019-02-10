#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[path zlib lodash express]>
moment = require \moment-timezone
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename
{constants} = require \../common/definitions
{APPEVT_TIME_SERIES_V1_DATA_POINTS} = constants
{funcs} = require \../common/webapi-helpers
{NG} = funcs


DEFAULT_SETTINGS =
  enabled: no


PROCESS_EMPTY_DATA = (id, profile, originalname, req, res) ->
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


PROCESS_CORRUPT_COMPRESSED_DATA = (id, profile, originalname, err, req, res) ->
  message = "#{profile}/#{id}/#{originalname} decompression failure."
  ERR err, message
  # Although the uploaded archive is not a valid gzip file,
  # we still need to accept it. Otherwise, the client will keep uploading
  # the corrupted archive file onto sensor-hub.
  #
  return NG message, -2, 200, req, res


PROCESS_CORRUPT_JSON_DATA = (id, profile, originalname, err, req, res) ->
  message = "#{profile}/#{id}/#{originalname} is invalid JSON data"
  ERR err, message
  # # Although the uploaded archive is not a valid json file,
  # we still need to accept it. Otherwise, the client will keep uploading
  # the corrupted archive file onto sensor-hub.
  #
  return NG message, -3, 200, req, res



PARSE_TIMESTAMP_V1 = (filename, profile, id, timezone, req) ->
  fmt = \YYYYMMDD_HHmmss
  name = path.basename filename, \.json.gz
  if not timezone?
    timezone = switch profile
      | \foop       => \Asia/Tokyo
      | \conscious  => \Asia/Tokyo
      | \dhvac      => \Asia/Taipei
      | otherwise   => \Asia/Taipei
    DBG "#{req.originalUrl.yellow}: guess timezone => #{timezone.cyan}"
  else
    DBG "#{req.originalUrl.yellow}: use timezone => #{timezone.cyan}"
  return moment.tz name, fmt, timezone


PARSE_TIMESTAMP = (version, filename, profile, id, timezone, req) ->
  try
    return PARSE_TIMESTAMP_V1 filename, profile, id, timezone, req if ( /\d\d\d\d\d\d_\d\d\d\d\d\d.json\.gz/ ).test filename
    WARN "unexpected format: #{filename} for #{profile}/#{id}"
  catch error
    WARN error, "unexpected error to parse #{filename} for #{profile}/#{id}"
  return moment!


PARSE_JSON = (buffer, done) ->
  try
    text = buffer.toString!
    json = JSON.parse text
  catch error
    return done error
  return done null, json



module.exports = exports =
  name: \webapi-legacy

  attach: (name, environment, configs, helpers) ->
    INFO "configs => #{JSON.stringify configs}"
    module.configs = lodash.merge {}, DEFAULT_SETTINGS, configs
    return <[web]>

  init: (p, done) ->
    {configs} = module
    {enabled} = configs
    if not enabled
      WARN "disabled!!"
      return done!
    {web} = context = @
    {REST_ERR, REST_DAT, UPLOAD} = web.get_rest_helpers!
    module.context = context
    hub = new express!
    hub.post '/:id/:profile', (UPLOAD.single \sensor_data_gz), (req, res) ->
      received = (new Date!) - 0
      {file, params, query} = req
      {id, profile} = params
      return NG "invalid file upload form", -1, 400, req, res unless file?
      {fieldname, originalname, size, buffer, mimetype} = file
      return NG "missing sensor_data_gz field", -1, 400, req, res unless fieldname == \sensor_data_gz
      return PROCESS_EMPTY_DATA id, profile, originalname, req, res if size is 0
      file.buffer = null
      filename = originalname
      bytes = buffer.length

      {tz} = query
      now = (new Date!) - 0
      time = PARSE_TIMESTAMP 1, filename, profile, id, tz, req
      diff = now - (time - 0)
      text = "#{diff}"
      DBG "#{req.originalUrl.yellow}: #{filename} (#{mimetype}) with #{bytes} bytes (time => #{time.format 'YYYY/MM/DD HH:mm:ss'}; diff => #{text.magenta}; local => #{req.query.local})"

      return PROCESS_EMPTY_DATA id, profile, filename, req, res if size is 0
      (zerr, raw) <- zlib.gunzip buffer
      return PROCESS_CORRUPT_COMPRESSED_DATA id, profile, filename, zerr, req, res if zerr?
      (jerr, data) <- PARSE_JSON raw
      return PROCESS_CORRUPT_JSON_DATA id, profile, filename, jerr, req, res if jerr?
      res.status 200 .json { code: 0, message: null, result: {id, profile, filename, bytes} }
      {items} = data
      INFO "#{req.originalUrl.yellow}: #{filename} (#{items.length} points) is decompressed from #{bytes} to #{raw.length} bytes"

      compressed-size = bytes
      raw-size = raw.length
      measured = time.valueOf!
      return context.emit APPEVT_TIME_SERIES_V1_DATA_POINTS, profile, id, items, do
        source: \toe1-upload
        upload: {filename, compressed-size, raw-size}
        timestamps: {measured, received}

    web.use-api \hub, hub, 1
    return done!

  fini: (p, done) ->
    return done!
