module.exports = exports =

  untrusted_ip:
    status: 403
    code: -1001
    message: "untrusted ip {{ip}} to access sensitive resource {{originalUrl}}"

  missing_developer:
    status: 401
    code: -1002
    message: "require developer and api token to access sensitive resource {{originalUrl}}"

  untrusted_developer:
    status: 403
    code: -1003
    message: "client with untrusted developer api token to access sensitive resource {{originalUrl}}"

  invalid_argument:
    status: 400
    code: -2001
    message: "Invalid Argument: {{err}}"

  missing_archive_at_creation:
    status: 400
    code: -2001
    message: "missing `archive` field in multipart/form-data for adding an archive"

  resource_unavailable:
    status: 404
    code: -2001
    message: "Resource Unavailable: {{err}}"

  archive_unavailable:
    status: 404
    code: -2002
    message: "{{err}}"

  missing_field:
    status: 400
    code: -3004
    message: "{{err}}"

  general_server_error:
    status: 500
    code: -1
    message: "{{err}}"

  not_implemented:
    status: 404
    code: -1
    message: "service {{originalUrl}} is not implemented yet"

  resource_not_implemented:
    status: 501
    code: -5001
    message: "Resource Unimplemented: {{err}}"

  remote_agent_error:
    status: 600
    code: -6001
    message: "{{err}}"
