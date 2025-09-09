#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[handlebars]>
errors = require \./errors
{services} = global.ys
{DBG, ERR, WARN, INFO} = services.get_module_logger __filename


class ErrorTemplate
  (@c, @name, @fields) ->
    {status, code, message} = fields
    @status = status
    @code = code
    @message = message
    @template = handlebars.compile message
    DBG "creating error-template for #{name.yellow}"

  produce: (url, context) ->
    {template, name, code, status} = self = @
    error = name
    message = template context
    result = {code, error, url, message}
    return {status, result}


class ResponseComposer
  (@errors) ->
    self = @
    self.templates = { [name, (new ErrorTemplate self, name, fields)] for name, fields of errors }
    DBG "errors: #{JSON.stringify errors}"

  compose-error: (req, res, name, err=null, data=null) ->
    {templates} = self = @
    t = templates[name]
    if t?
      {ip, originalUrl} = req
      {status, result} = t.produce originalUrl, {ip, originalUrl, err}
      result['data'] = data if data?
      ERR "#{req.method} #{req.originalUrl.yellow} #{name.red} ==> #{(JSON.stringify result).cyan}"
      return res.status status .json result
    else
      ERR "#{req.url.yellow} #{name.green} json = unknown error"
      return res.status 500 .json {error: "unknown error: #{name}"}

  compose-data: (req, res, data, status=200) ->
    code = 0
    error = null
    message = null
    url = req.originalUrl
    return res.status status .json {code, data, error, message, url}


REST_ERR = (req, res, name, err=null, data=null) -> return module.composer.compose-error req, res, name, err, data
REST_DAT = (req, res, data, status=200) -> return module.composer.compose-data req, res, data, status

module.composer = new ResponseComposer errors

module.exports = exports = {REST_ERR, REST_DAT}
