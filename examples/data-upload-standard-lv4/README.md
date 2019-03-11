
# data-upload-standard-lv4

The example demonstrates uploading sensor data to SensorHub with simple JSON POST, and using BASH to implement monitor script.


## Example Code

The example is quite simple. Using curl to visit one site (e.g. https://www.google.com) regularly, print out network performance metrics as json, and pipe to httpie to post to SensorHub to receive:

```bash
#!/bin/bash
#

function initialize_variables {
	[ "" == "${URL}" ] && export URL="https://www.google.com"
	[ "" == "${SITE}" ] && export SITE="google"
	[ "" == "${SENSOR_HUB}" ] && export SENSOR_HUB="http://localhost:7000"
	[ "" == "${PROFILE}" ] && export PROFILE="sandbox"
	[ "" == "${ID}" ] && export ID=$(hostname)

	[ "" == "$(which curl)" ] && echo "missing curl, please install" && exit 1
	[ "" == "$(which http)" ] && echo "missing httpie, please install" && exit 1
}

function run {
	while true; do
		curl \
			-w '{"namelookup": %{time_namelookup},"connect": %{time_connect},"appconnect": %{time_appconnect},"pretransfer": %{time_pretransfer},"redirect": %{time_redirect},"starttransfer": %{time_starttransfer},"total": %{time_total}}' \
			-D /tmp/tmpbYHj0P \
			-o '/tmp/tmpmjeMeW' \
			-s \
			-S ${URL} \
			| http -v ${SENSOR_HUB}/api/v3/upload/${PROFILE}/${ID}/connectivity/internet/curl/${SITE}
		sleep 3
	done
}


initialize_variables
run $@
```

Here are the fields in the HTTP POST body:

  - namelookup
  - connect
  - appconnect
  - pretransfer
  - redirect
  - starttransfer
  - total

To run this example to submit data to SensorHub running on the localhost with port 7000, please type:

```bash
$ SENSOR_HUB=http://localhocat:7000 ./monitor
```

To run this example to submit data to SensorHub running on the TicTacToe cloud, please specify the environment variable `SENSOR_HUB` when running nodejs:

```bash
$ SENSOR_HUB=https://hub.tic-tac-toe.io ./monitor
```

Or, you can consider to run SensorHub, TSDB (influxdb 1.7), Dashboard (Grafana 6.0) on your local machine with Docker:

```bash
# run 3 services with Docker Compose
#
$ docker-compose up

# open another terminal, and change to same directory:
#
$ SENSOR_HUB=http://localhost:7000 node ./index.js

# open browser, and visit http://localhost:3000/d/b8ZebvCmk/connectivity-stats
# with user `admin` and password `t2tisawesome`.
```
