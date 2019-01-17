#!/usr/bin/env node
'use strict';

var http = require('http');
var util = require('util');
var zlib = require('zlib');
var colors = require('colors');
var express = require('express');
var multer = require('multer');
var prettyjson = require('prettyjson');

const HOST = '0.0.0.0';
const PORT = 9998;
const UPLOAD_NAME = 'sensor_json_gz';

var DUMP = function (json) {
    var text = prettyjson.render(json, { inlineArrays: true, defaultIndentation: 4 });
    var lines = text.split('\n');
    lines.forEach(l => {
        console.log(`\t${l}`);
    });
    console.log("\t--------");
};

var DUMP_MEASUREMENTS = function (measurements) {
    measurements.forEach(m => {
        var [timestamp, p_type, p_id, s_type, s_id, field_sets] = m;
        var text = util.inspect(field_sets);
        timestamp = timestamp.toString();
        text = text.split('\n').join(' ');
        console.log(`\t${timestamp.gray}: ${p_type.magenta}/${p_id.magenta}/${s_type.magenta}/${s_id.magenta} => ${text}`);
    });
};

var upload = multer({ storage: multer.memoryStorage() });

var web = express();
web.set('trust proxy', true);

/**
 * Configure SensorHub's http forwarder with following settings in order to
 * forward latest sensor data measurements to this express server:
 * 
 *  http-forwarder:
 *      verbose: false
 *      destinations:
 *          - name: test
 *            enabled: true
 *            url: https://hooks.abc.com/x/y/z
 *            compressed: true
 *            health_check: false
 *            url_append: true
 *            request_opts:
 *              qs: {token: 'XXX'}
 * 
 * Then, SensorHub shall forward sensor data to `https://hooks.abc.com/x/y/z/${profile}/${id}`.
 */
web.post('/x/y/z/:profile/:id', upload.single(UPLOAD_NAME), (req, res) => {
    var { query, file, params } = req;
    var { profile, id } = params;
    var { timestamp } = query;
    var { fieldname, originalname, size, buffer } = file;
    console.log(`multiparts-upload: ${req.originalUrl.yellow}: ${req.headers['content-length']} bytes`);
    zlib.gunzip(buffer, (zerr, raw) => {
        if (zerr) {
            return console.log(`failed to decompress archive ${profile}/${id}/${timestamp}, zerr: ${zerr}`);
        }
        var text = raw.toString();
        var data = JSON.parse(text);
        var { measurements, context } = data;
        console.log(`\tcompressed: ${buffer.length}, decompressed: ${raw.length} bytes`);
        console.log(`\t--------`);
        DUMP({ fieldname, originalname, size });
        DUMP(context)
        DUMP_MEASUREMENTS(measurements);
    });
    res.status(200).end();
});

/**
 * To indicate SensorHub that the service is alive to receive http forwarding sensor
 * data.
 */
web.options('/x/y/z', (req, res) => {
    console.log(`healthy check from ${req.ip}`);
    res.status(200).end();
});

var server = http.createServer(web);
server.on('listening', () => {
    console.log(`listening ${HOST}:${PORT}`);
});
server.listen(PORT, HOST);