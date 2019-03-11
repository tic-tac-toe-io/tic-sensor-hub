# tic-sensor-hub

Data hub for time series data from TOE devices or TAC apps.


## Data Upload APIs


### Standard Data Upload (4 Levels)

`POST /api/v3/upload/:profile/:id/:p_type/:p_id/:s_type/:s_id` (**application/json** with JSON body)

The simplest API to receive the sensor data update with single measurement. [data-upload-standard-lv4](examples/data-upload-standard-lv4) demonstrates to use BASH script with `curl` to implement a connectivity stat monitor and regularly submit data to this api endpoint.


### Standard Data Upload (2 Levels)

`POST /api/v3/upload/:profile/:id/:p_type/:p_id` (**application/json** with JSON body)

T.B.D.


### TOE1 Legacy Sensor Data Upload

`POST /api/v1/hub/:id/:profile` (**multipart/form-data** with file upload)

This API endpoint receives sensor data uploaded by TOE 1.0 devices, and the example [data-upload-toe1-legacy](examples/data-upload-toe1-legacy) demonstrates how the data is upload, in protocol and archive file format.


### TOE3 Sensor Data Upload

`POST /api/v3/upload-archive/:profile/:id/:type` (**multipart/form-data** with file upload)

TOE 3.0 devices support the new sensor data archive format (that improve size efficiency a lots). Please note, most TOE 3.0 devices support to upload data to above API endpoint, but a few TOE 3.0 devices shipped at early days might only support to upload data to another API endpoint `/api/v3/upload/:profile/:id`. For compatibility, both 2 API endpoints are supported in SensorHub.


### SensorHub Hook

`POST /api/v3/hook/http-forwarder/:profile/:id` (**multipart/form-data** with file upload)

SensorHub supports HTTP Forwarder broker that uses HTTP POST with JSON body to forward sensor data to next backend server to proceed, and SensorHub itself can also play such backend server role to receive sensor data from another instance of SensorHub with this api endpoint.



## Todo

- [x] docker image for SensorHub
- [x] docker compose to run SensorHub, InfluxDB, Grafana on the same local machine
- [] replace bunyan with [pino](https://getpino.io/#/) which is more lightweight
