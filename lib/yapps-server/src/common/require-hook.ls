require! <[path]>
#
# yap-require-hook
#
module.initialized = no
module.loaded-modules = []

#
# Inspired by
#
# http://fredkschott.com/post/2014/06/require-and-the-module-system/
#

FIND_MODULE = (instance) ->
  {loaded-modules} = module
  ret = null
  for let lm, i in loaded-modules
    ret := lm if lm.m === instance
  return ret

FIND_MODULE_FROM_SYSTEM = (instance) ->
  {_cache} = system = require \module
  ret = null
  for fullpath, m of _cache
    ret := m if m.exports == instance
  return ret

# Hook to `module.js` in nodejs
#
HOOK = ->
  system = require \module
  {_load} = system
  system._load = (request, parent, isMain) ->
    {pre, post, loaded-modules} = module
    context = pre request, parent, isMain if pre?
    global <<< context if context?
    m = _load request, parent, isMain
    post request, m if post?
    {filename, paths} = parent
    return exports.add-reference m, request, {filename}



module.exports = exports =

  install: (pre, post) ->
    return if module.initialized
    module.pre = pre if pre?
    module.post = post if post?
    module.initialized = yes
    HOOK!

  lookup: (m) ->
    result = FIND_MODULE m
    return null unless result?
    {req, parent} = result
    sm = FIND_MODULE_FROM_SYSTEM m
    {id, filename} = sm
    filepath = filename
    return {req, id, filepath}

  add-reference: (m, req, parent) ->
    {loaded-modules} = module
    loaded-modules.push {m, req, parent}
    return m
