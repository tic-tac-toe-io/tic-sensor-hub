#!/usr/bin/env node
'use strict';

var { exec } = require('child_process');
var request = require('request');
var colors = require('colors');
var os = require('os');
var fs = require('fs');
var zlib = require('zlib');
var request = require('request');
var moment = require('moment-timezone');

var { SENSOR_HUB } = process.env;
if (SENSOR_HUB) {
    console.log(`SENSOR_HUB: ${SENSOR_HUB.red}`);
}
else {
    SENSOR_HUB = 'http://localhost:7000';
    console.log(`SENSOR_HUB: ${SENSOR_HUB.red} (default)`);
}

global.items = [];
global.profile = 'sandbox';
global.id = os.hostname();
global.timezone = moment.tz.guess();

/**
 * Inspired by https://github.com/reorx/httpstat
 */
var text = `{
    "namelookup": %{time_namelookup},
    "connect": %{time_connect},
    "appconnect": %{time_appconnect},
    "pretransfer": %{time_pretransfer},
    "redirect": %{time_redirect},
    "starttransfer": %{time_starttransfer},
    "total": %{time_total},
    "speed_download": %{speed_download},
    "speed_upload": %{speed_upload}
}`
var format = text.split('\n').join('\\n');

var convert_to_milliseconds = function (o) {
    for (const key in o) {
        o[key] = parseFloat((o[key] * 1000).toFixed(3));
    }
    return o;
}

var dump_values = function (o, color = 'cyan') {
    var keys = Object.keys(o);
    var tokens = keys.map((key) => {
        var v = o[key].toString();
        return `${key}:${v[color]}`;
    });
    return tokens.join(' ');
}

var enqueue_connectivity_stats = function (site, metric, pairs, unit_length = '') {
    let board_type = 'connectivity';
    let board_id = site;
    let sensor = metric;
    for (const key in pairs) {
        let data_type = key;
        let desc = { board_type, board_id, sensor, data_type };
        let value = pairs[key];
        let updated_at = (new Date()).toISOString();
        let type = typeof (value);
        let data = { updated_at, value, type, unit_length };
        let item = { desc, data };
        global.items.push(item);
    }
}

var dequeue = function () {
    let { items, profile, id, timezone } = global;
    let payload = { profile, id, items };
    global.items = [];
    let text = JSON.stringify(payload);
    console.log(`\npayload: ${JSON.stringify(payload)}\n`);

    let buffer = Buffer.from(text);
    zlib.gzip(buffer, (zerr, compressed) => {
        if (zerr) {
            console.dir(zerr);
            return;
        }
        let rawSize = buffer.length;
        let compressedSize = compressed.length;
        let ratio = ((compressedSize / rawSize) * 100).toFixed(1);
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
            tz: timezone,
            local: Date.now().valueOf()
        };
        console.log(`submitting data to ${url.red}, with ${filename} ${compressedSize} bytes (original: ${rawSize} bytes, ${ratio.magenta}%)`);
        request.post({ url, qs, formData }, (err, rsp, body) => {
            if (err) {
                console.dir(err);
                return;
            }
        });
    });
}

var check_http_connection_stats = function (site, url) {
    var command = `curl -w '${format}' -D /tmp/tmpbYHj0P -o '/tmp/tmpmjeMeW' -s -S '${url}'`;
    exec(command, (err, stdout, stderr) => {
        if (err) {
            console.log(`err: ${err}`);
            return;
        }
        var timestamps = JSON.parse(stdout.toString());

        let upload = timestamps['speed_upload'];
        let download = timestamps['speed_download'];
        let speed = { upload, download };
        delete timestamps['speed_upload'];
        delete timestamps['speed_download'];

        let dns = timestamps['namelookup'];
        let connection = timestamps['connect'] - timestamps['namelookup'];
        let ssl = timestamps['pretransfer'] - timestamps['connect'];
        let server = timestamps['starttransfer'] - timestamps['pretransfer'];
        let transfer = timestamps['total'] - timestamps['starttransfer'];

        let ranges = { dns, connection, ssl, server, transfer };

        // Transform `seconds` to `milliseconds`.
        timestamps = convert_to_milliseconds(timestamps);
        ranges = convert_to_milliseconds(ranges);

        console.log(`${site} (${url.yellow}):
            timestamps => ${dump_values(timestamps, 'blue')}
            ranges => ${dump_values(ranges, 'cyan')}
            speed => ${dump_values(speed, 'green')}`
        );

        enqueue_connectivity_stats(site, 'timestamps', timestamps, 'milliseconds');
        enqueue_connectivity_stats(site, 'timestamps', ranges, 'milliseconds');
        enqueue_connectivity_stats(site, 'timestamps', speed, 'bytes/s');
    });
}

var check_connectivity_google = function () {
    return check_http_connection_stats('google', 'https://www.google.com');
}

var check_connectivity_facebook = function () {
    return check_http_connection_stats('facebook', 'https://www.facebook.com');
}

setInterval(check_connectivity_google, 2800);
setInterval(check_connectivity_facebook, 3700);
setInterval(dequeue, 10000);

console.log(`please press Ctrl + C to stop ...`);
check_connectivity_google();
check_connectivity_facebook();
