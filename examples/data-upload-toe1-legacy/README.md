
# data-upload-toe1-legacy

The example demonstrates uploading sensor data to SensorHub with TOE 1.0 data archive format.

## Data Archive Format

Here is one sample of TOE 1.0 data archive, which is a standard JSON object with 3 fields: `profile`, `id`, and `items`. The data archive is typically stored in `[YYYYMMDD_HHmmss].json.gz` file archive (compressed with gzip algorithm).

```json
{
  "profile": "sandbox",
  "id": "grandia",
  "items": [
    {
      "desc": {
        "board_type": "connectivity",
        "board_id": "google",
        "sensor": "timestamps",
        "data_type": "namelookup"
      },
      "data": {
        "updated_at": "2019-03-03T12:35:05.981Z",
        "value": 4.498,
        "type": "number",
        "unit_length": "milliseconds"
      }
    },
    {
      "desc": {
        "board_type": "connectivity",
        "board_id": "google",
        "sensor": "timestamps",
        "data_type": "connect"
      },
      "data": {
        "updated_at": "2019-03-03T12:35:05.981Z",
        "value": 11.935,
        "type": "number",
        "unit_length": "milliseconds"
      }
    },
    ...
  ]
}
```

## Data Upload Protocol

The data upload protocol is based on HTTP File Upload with Form (multiparts), and SensorHub uses `${SENSOR_HUB}/api/v1/hub/:id/:profile` REST API endpoint to receive the data archive. The REST API expects the data archive file is uploaded in the Form Field `sensor_data_gz` with filename `[YYYYMMDD_HHmmss].json.gz`, and if possible, the timezone information (`tz` field in query string) and local time (`local` field in query string) shall be also supplied to help SensorHub detect time shifts.

Here is protocol sample code:

```javascript
let data = {profile, id, items};
zlib.gzip(Buffer.from(JSON.stringify(data)), (zerr, compressed) => {
    if (zerr) {
        console.dir(zerr);
        return;
    }
    let now = moment();
    let url = `${SENSOR_HUB}/api/v1/hub/${id}/${profile}`;
    let filename = `/tmp/${now.format('YYYYMMDD_HHmmss')}.json.gz`;
    let contentType = 'application/gzip';
    let formData = {
        sensor_data_gz: {
            value: compressed,
            options: { filename, contentType }
        }
    };
    let qs = {
        tz: moment.tz.guess(),
        local: Date.now().valueOf()
    };
    request.post({ url, qs, formData }, (err, rsp, body) => {
        if (err) {
            console.dir(err);
            return;
        }
    });
});
```


## Example Code

This example `data-upload-toe1-legacy` performs regular connectivity checking to https://www.google.com and https://www.facebook.com based on [httpstat](https://github.com/reorx/httpstat) concept, and upload following metric data (as sensor type and data type) to SensorHub with TOE 1.0 data format and protocol:

- timestamps
  - namelookup
  - connect
  - appconnect
  - pretransfer
  - redirect
  - starttransfer
  - total
- ranges
  - dns
  - connection
  - ssl
  - server
  - transfer
- speed
  - upload
  - download

The board_type is specified as `connectivity`, while board_id is specified with either `google` or `facebook`. This example uploads data to SensorHub with profile `sandbox` and uses current machine's hostname as `id` in upload protocol.


To run this example to submit data to SensorHub running on the localhost with port 7000, please type:

```bash
$ node ./index.js
```

To run this example to submit data to SensorHub running on the TicTacToe cloud, please specify the environment variable `SENSOR_HUB` when running nodejs:

```bash
$ SENSOR_HUB=https://hub.tic-tac-toe.io node ./index.js
```
