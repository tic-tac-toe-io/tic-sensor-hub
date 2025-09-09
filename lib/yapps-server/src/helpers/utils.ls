require! <[colors prettyjson handlebars path]>

DUMMY = ->
  return

COLORIZED = (v) ->
  t = typeof v
  return v.yellow if t is \string
  return v.to-string! .green if t is \number
  return v.to-string! .magenta if t is \boolean and v
  return v.to-string! .red if t is \boolean and not v
  return (JSON.stringify v).blue if t is \object
  return v

PRETTIZE_KVS = (kvs, separator=", ") ->
  xs = [ "#{k.gray}:#{COLORIZED v}" for k, v of kvs ]
  return xs.join separator

PRINT_PRETTY_JSON = (name, config, idents=1, output=console.error) ->
  return output "#{name}: \n#{(JSON.stringify config, null, ' ').gray}" unless prettyjson?
  text = prettyjson.render config, do
    keysColor: \gray
    dashColor: \green
    stringColor: \yellow
    numberColor: \cyan
    defaultIndentation: 4
    inlineArrays: yes
  xs = text.split '\n'
  tabs = "\t" * idents
  output "#{name}:"
  [ output "#{tabs}#{x}" for x in xs ]
  output ""

MERGE_JSON_TEMPLATE = (json, context) ->
  text = JSON.stringify json
  template = handlebars.compile text
  text = template context
  return JSON.parse text

##
# Inspired by https://github.com/indexzero/node-pkginfo/blob/master/lib/pkginfo.js
#
LOAD_PACKAGE_JSON = (app_dir, file_path, dir=null) ->
  dir = path.dirname file_path unless dir?
  throw new Error "Could not find package.json up from #{file_path}" if dir is path.dirname dir
  throw new Error "Could not find package.json until app_dir: #{app_dir} from #{file_path}" if dir is app_dir
  throw new Error "Cannot find package.json from unspecified directory" unless dir? or dir is \.
  try
    p = "#{dir}/package.json"
    debug "looking for #{p}"
    json = require p
  catch error
    DUMMY error
  return {p, json} if json?
  return LOAD_PACKAGE_JSON app_dir, file_path, path.dirname dir


module.exports = exports = {DUMMY, COLORIZED, PRETTIZE_KVS, PRINT_PRETTY_JSON, MERGE_JSON_TEMPLATE, LOAD_PACKAGE_JSON}
