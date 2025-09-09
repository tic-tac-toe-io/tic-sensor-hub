
#
# Predefined variables for configuration file:
#
#   - app_name
#   - process_name => mst, w00, w01, w02, w03...
#   - app_dir
#   - work_dir
#   - logs_dir
#   - startup_time
#


const opts =
  web:
    port: 3000
    api: 3
    upload_storage: \memory
    upload_path: "{{work_dir}}/web/upload/{{process_name}}"

  #
  # DO NOT USE any handlebars template variables (e.g. process_name) in logger
  # section because they are never merged.
  #
  logger:
    rotating_file_stream:
      period: \daily
      threshold: \1g    # The maximum size for a log file to reach before it's rotated.
      totalFiles: 60    # Keep 60 days (2 months) of log files.

module.exports = exports = opts