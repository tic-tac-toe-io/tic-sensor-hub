
## http-form-gz-callback

This is an example demonstrating how to setup a receiver server based on [Express](http://expressjs.com/) to receive sensor data forwarded from an SensorHub instance.

### Server Setup

Setup the express server, and run it locally to listen port 9998:

```text
$ git clone https://github.com/tic-tac-toe-io/tic-sensor-hub.git
$ cd tic-sensor-hub/examples/http-form-gz-callback
$ npm install
$ node ./index.js
```

Please note, the example serves following 2 URLs:

```javascript
// Receive sensor data forwarded from SensorHub
web.post('/x/y/z/:profile/:id', upload.single(UPLOAD_NAME), (req, res) => { ... });

// Health check from SensorHub
web.options('/x/y/z', (req, res) => { res.status(200).end(); });
```

SensorHub uses 2nd URL to check the health of receiver server every 60 seconds. SensorHub expects HTTP status 200 response to treat the receiver server healthy, and SensorHub only forwards sensor data to receiver server when it is healthy.



### SensorHub Configuration

One destination (receiver server) shall be added to SensorHub's configuration. Here is one example (assuming SensorHub is running in the subnet same as the receiver server):

```yaml
http-forwarder:
  verbose: false
  destinations:
    - name: local
      enabled: true
      health_check: true
      url_append: true
      url: http://192.168.1.100:9998/x/y/z
      compressed: true
      request_opts: {qs: {token: 'HELLO'}}
```

Or, you can configure a receiver server outside the subnet that SensorHub is running. For example:

```yaml
http-forwarder:
  verbose: false
  destinations:
    - name: local
      enabled: true
      health_check: true
      url_append: true
      url: https://abc.com/x/y/z
      compressed: true
      request_opts: {qs: {token: 'HELLO'}}
```
