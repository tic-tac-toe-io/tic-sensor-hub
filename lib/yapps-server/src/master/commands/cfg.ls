require! <[debug fs]>
debug = debug \yapps-server:command:cfg

module.exports = exports = (pathes) ->
  return do
    command: \cfg
    aliases: <[config conf]>
    describe: "dump the default configurations"
    handler: (argv) ->
      debug "handler() => %o", argv
      debug "handler() => pathes: %o", pathes
      {app_dir} = pathes
      buffer = fs.readFileSync "#{app_dir}/config/default.yml"
      console.log buffer.toString! if buffer?
      process.exit 0
