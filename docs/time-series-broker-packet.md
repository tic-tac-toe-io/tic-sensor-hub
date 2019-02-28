## Background

SensorHub supports multiple api endpoints (e.g. TOE1 legacy sensor archive, TOE3 sensor archive, MQTT, and so on...) to receive sensor data updates, and transform these updates to an internal event `APPEVT_TIME_SERIES_V3_MEASUREMENTS` (**ts::v3::measurements**) (defined in [definitions.ls](../src/common/definitions.ls)) with time series data payload to broadcast. Then, all enabled brokers in SensorHub shall subscribe `APPEVT_TIME_SERIES_V3_MEASUREMENTS` event to proceed those sensor data updates.


## Event Payload

The payload of `APPEVT_TIME_SERIES_V3_MEASUREMENTS` event contains 4 fields:

| name | description | examples |
|----|----|----|----|
| profile | the business category for these sensor data updates, or the project name | `sandbox`, `autohome`, ... |
| id | the globally unique identity for the physical device that measures sensor data objects to generate the update event | `BBGW16053525`, `000000003d1d1c36 ` |
| measurements | the array of measured data objects for the sensor data update | |
| context | the background information for processing the sensor data update | |


So, the callback function for sensor update event shall have following prototype:

```javascript
app.on(APPEVT_TIME_SERIES_V3_MEASUREMENTS, (profile, id, measurements, context) => {})
```

### context

`context` is a JSON object to describe the contextual information for the measured data objects (`measurements`), including these fields:

| field | mandatory | description | examples |
|----|----|----|----|
| `source` | yes | the source of api endpoint to receive this sensor data update | `toe1-upload`, `toe3-upload-alpha`, `toe3-upload`, `toe3-mqtt`, ... |
| `upload.filename` | optional | filename of archive file (e.g. `*.json.gz`) with those measured data objects for the sensor update; only available when the api endpoint uses Form-based file upload | |
| `upload.compressedSize` | optional | the file size of archive file before decompression | |
| `upload.rawSize` | optional | the file size of archive file after decompression | |
| `timestamps.measured` | yes | the timestamp (epoch time) for the 1st data object of this sensor data update event, measured on the physical device | `1551126233395` => 2019-02-25T20:23:53.395Z |
| `timestamps.received` | yes | the timestamp that api endpoint of SensorHub receives this sensor update | |
| `timestamps.transformed` | optional | the timestamp that api endpoint transforms sensor update to internal event `APPEVT_TIME_SERIES_V3_MEASUREMENTS`; only available when the api endpoint receives data format other the payload described in this document, such as TOE1 legacy api endpoint | |
| `timestamps.delta` | optional | time difference between api data receiving time and device local time for data uploading; only available when api endpoint is `toe3-upload` because TOE3 uploads sensor data archive to `/api/v3/upload-archive/:profile/:id/:type` with one query-string field **epoch** to describe the device's local time to upload. Please note, the time difference is at least impacted by 2 factors: a) the epoch time difference between SensorHub and TOE device. b) network latency to upload archive | |

Here is one example of `context` object for sensor data received from a device with TOE 3.0 software:

```json
  "context": {
    "source": "toe3-upload",
    "upload": {
      "filename": "00025-000D2C378E-1551126262574-20190226-052422.json.gz",
      "compressedSize": 1890,
      "rawSize": 5165
    },
    "timestamps": {
      "measured": 1551126233395,
      "received": 1551126264726,
      "transformed": 1551126264727,
      "delta": 2149
    }
  }
```

### measurements

`measurements` is an array of measured data objects. Each data object is an array with following elements:

| index | name | type | description | example |
|---|---|---|---|---|
| 0 | timestamp | integer | the timestamp that the data object is measured on the device; please note, it has been calibrated when these measurements are received by `toe3-upload` api endpoint | `1551126262420` => 2019-02-25T20:24:22.420Z |
| 1 | p_type | string | the type of peripheral object associated with the device, that measures the data object | `sensorboard`, `linux`, `bluetooth_heater` |
| 2 | p_id | string | the unique id of peripheral object (under same peripheral type) | `1`, `00:e0:4c:68:d3:82`, ... |
| 3 | s_type | string | the type of sensor object on the peripheral object that measures the data object | `iaq_co2`, `sht21`, ... |
| 4 | s_id | string | the unique id of sensor object (under same sensor type) on the peripheral object that measures the data object | `0`, `1`, `2`, `lower`, `higher`, ... |
| 5 | field_values | json object | the key-value pairs for the data type(s) and measured value(s) | `{"co2": 1843, "tvoc": 886}` |

Here are some examples:

1. At 2019-02-25T20:24:17.637Z, the **co2** and **tvoc** values measured by the first `iaq_co2` sensor on the peripheral object `sensorboard` connected via `ttyO1` (using UART device name as `p_id`)

  ```
[ 1551126257637, "sensorboard", "ttyO1", "iaq_co2", "0", {"co2": 1843, "tvoc": 886} ]
  ```

2. At 2019-02-25T20:24:17.235Z, the **temperature** and **humidity** values measured by the first [hdc1000](http://processors.wiki.ti.com/index.php/CC2650_SensorTag_User%27s_Guide#Humidity_Sensor) sensor on the TI SensorTag (CC2650) whose id is its BLE mac address: `00:e0:4c:68:d3:82`.

  ```
[ 1551126257235, "ti_sensortag", "00:e0:4c:68:d3:82", "hdc1000", "0", {"temperature": 26.5, "humidity": 74} ]
  ```


### full example of payload

Here is one complete example of payload data for `APPEVT_TIME_SERIES_V3_MEASUREMENTS` event:

```json
{
  "profile": "sandbox",
  "id": "BBGW16053525",
  "measurements": [
    [
      1551126262420,
      "mainboard",
      "ttyi2c1",
      "ambient_light",
      "0",
      {
        "raw": 4,
        "adc": 0.0018,
        "illuminance": 1.05,
        "illuminance_raw": 1
      }
    ],
    [
      1551126254175,
      "linux",
      "7F000001",
      "cpu",
      "_",
      {
        "percentage": 31.1
      }
    ],
    [
      1551126257235,
      "sensorboard",
      "ttyO1",
      "humidity",
      "0",
      {
        "temperature": 20.7,
        "humidity": 70.3,
        "temperature_raw": 23.3,
        "humidity_raw": 59.9
      }
    ],
    [
      1551126257337,
      "sensorboard",
      "ttyO1",
      "barometric_pressure",
      "0",
      {
        "pressure": 1018.01,
        "pressure_error": null,
        "pressure_raw": 1020.7
      }
    ],
    [
      1551126257436,
      "sensorboard",
      "ttyO1",
      "ndir_co2",
      "0",
      {
        "co2": 477,
        "co2_error": null,
        "co2_raw": 477
      }
    ],
    [
      1551126257637,
      "sensorboard",
      "ttyO1",
      "iaq_co2",
      "0",
      {
        "co2": 565,
        "co2_error": null,
        "tvoc": 157,
        "tvoc_error": null,
        "tvoc_raw": 157
      }
    ],
    [
      1551126257737,
      "sensorboard",
      "ttyO1",
      "iaq_dust",
      "0",
      {
        "dust": 164.5,
        "dust_error": null
      }
    ],
    [
      1551126257836,
      "sensorboard",
      "ttyO1",
      "sound",
      "0",
      {
        "value": 0
      }
    ],
    [
      1551126257937,
      "sensorboard",
      "ttyO1",
      "led_matrix",
      "0",
      {
        "value": 305
      }
    ],
    [
      1551126258037,
      "sensorboard",
      "ttyO1",
      "rom",
      "0",
      {
        "value": null,
        "value_raw": 0
      }
    ],
    [
      1551126261540,
      "linux",
      "7F000001",
      "wireless_quality",
      "wlan0",
      {
        "link": 0,
        "signal": 0,
        "noise": 0
      }
    ],
    [
      1551126261540,
      "linux",
      "7F000001",
      "wireless_discarded",
      "wlan0",
      {
        "nwid": 0,
        "misc": 0,
        "retry": 0,
        "crypt": 0,
        "frag": 0
      }
    ],
    [
      1551126255674,
      "linux_process",
      "timestamp_logging",
      "python",
      "_",
      {
        "uptime": 220962.62659692764,
        "cpu": 0,
        "memory": 1.3820498702115944
      }
    ],
    [
      1551126255674,
      "linux_process",
      "DeviceController",
      "native",
      "_",
      {
        "uptime": 220942.40519309044,
        "cpu": 0,
        "memory": 0.9360497128923149
      }
    ],
    [
      1551126255674,
      "linux_process",
      "sensor_web3",
      "node",
      "_",
      {
        "uptime": 220938.8603913784,
        "cpu": 0,
        "memory": 10.089671989302289
      }
    ],
    [
      1551126255674,
      "linux_process",
      "stats",
      "python",
      "_",
      {
        "uptime": 220931.25482463837,
        "cpu": 0,
        "memory": 1.7462440022024701
      }
    ],
    [
      1551126255674,
      "linux_process",
      "wstty_agent",
      "node",
      "_",
      {
        "uptime": 220922.81434965134,
        "cpu": 0,
        "memory": 7.486824510343743
      }
    ],
    [
      1551126255674,
      "linux_process",
      "toe_agent",
      "node",
      "_",
      {
        "uptime": 48611.76945757866,
        "cpu": 0,
        "memory": 11.740737827420752
      }
    ],
    [
      1551126238266,
      "linux",
      "7F000001",
      "cpu_loads",
      "0",
      {
        "percentage": 12.6
      }
    ],
    [
      1551126255047,
      "linux",
      "7F000001",
      "virtual_memory",
      "_",
      {
        "inactive": 45940736,
        "active": 385327104,
        "shared": 495616,
        "available": 379060224,
        "total": 520724480,
        "used": 129761280,
        "percentage": 27.2,
        "free": 61276160,
        "slab": 19193856,
        "buffers": 185241600,
        "cached": 144445440
      }
    ],
    [
      1551126255767,
      "linux",
      "7F000001",
      "net_io_counters",
      "eth0",
      {
        "errout": 0,
        "dropin": 0,
        "packets_recv": 636792,
        "packets_sent": 321696,
        "errin": 0,
        "bytes_recv": 68351145,
        "dropout": 0,
        "bytes_sent": 138709250
      }
    ],
    [
      1551126255767,
      "linux",
      "7F000001",
      "net_io_counters",
      "wlan0",
      {
        "errout": 0,
        "dropin": 0,
        "packets_recv": 0,
        "packets_sent": 0,
        "errin": 0,
        "bytes_recv": 0,
        "dropout": 0,
        "bytes_sent": 0
      }
    ]
  ]
}
```