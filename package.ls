#!/usr/bin/env lsc -cj
#

# Known issue:
#   when executing the `package.ls` directly, there is always error
#   "/usr/bin/env: lsc -cj: No such file or directory", that is because `env`
#   doesn't allow space.
#
#   More details are discussed on StackOverflow:
#     http://stackoverflow.com/questions/3306518/cannot-pass-an-argument-to-python-with-usr-bin-env-python
#
#   The alternative solution is to add `envns` script to /usr/bin directory
#   to solve the _no space_ issue.
#
#   Or, you can simply type `lsc -cj package.ls` to generate `package.json`
#   quickly.
#

# package.json
#
name: \tic-sensor-hub

author:
  name: ['Yagamy']
  email: 'yagamy@t2t.io'

description: 'Hub for sensor data collection'

version: \0.1.0

repository:
  type: \git
  url: ''

main: \index

dependencies:
  \yapps-server : \tic-tac-toe-io/yapps-server
  \request : \*
  \moment-timezone : \*
  \influx : \*

devDependencies: {}

optionalDependencies: {}
