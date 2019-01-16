#!/usr/bin/env node
'use strict';

var http = require('http');
var util = require('util');
var colors = require('colors');
var express = require('express');
var multer = require('multer');
var bodyParser = require('body-parser');
var prettyjson = require('prettyjson');

const HOST = '0.0.0.0';
const PORT = 9999;

var DUMP = function(json) {
    var text = prettyjson.render(json, {inlineArrays: true, defaultIndentation: 4});
    var lines = text.split('\n');
    lines.forEach(l => {
        console.log(`\t${l}`);
    });
};

var DUMP_MEASUREMENTS = function(measurements) {
    measurements.forEach(m => {
        var [timestamp, p_type, p_id, s_type, s_id, field_sets] = m;
        var text = util.inspect(field_sets);
        timestamp = timestamp.toString();
        text = text.split('\n').join(' ');
        console.log(`\t${timestamp.gray}: ${p_type.magenta}/${p_id.magenta}/${s_type.magenta}/${s_id.magenta} => ${text}`);
    });
};

var upload = multer({ storage: multer.memoryStorage() });
var j = bodyParser.json();

var web = express();
web.set('trust proxy', true);
web.post('/a/b/c', j, (req, res) => {
    var {profile, id, measurements, context} = req.body;
    console.log(`${req.originalUrl.yellow}: ${req.headers['content-length']} bytes`);
    DUMP(context)
    DUMP_MEASUREMENTS(measurements);
    res.status(200).end();
});

var server = http.createServer(web);
server.on('listening', () => {
    console.log(`listening ${HOST}:${PORT}`);
});
server.listen(PORT, HOST);