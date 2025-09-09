//
// Copyright (c) 2018 T2T Inc. All rights reserved
// https://www.t2t.io
// https://tic-tac-toe.io
// Taipei, Taiwan
//
'use strict';

var colors = require('colors');
var livescript = require('livescript');
var debug = require('debug')('yapps-server:index');
var filepath = './src/bootstrap';
var bootstrap = null;

debug("process.argv: %o", process.argv);
debug("require.resolve(colors): %o", require.resolve('colors'));
debug("require.resolve(livescript): %o", require.resolve('livescript'));
// debug("require.cache: %o", require.cache);

var livescript = require('livescript');
debug("successfully load livescript");

/**
 * Loading from ${__dirname}/src/bootstrap.ls
 */
try {
    if (!bootstrap) {
        debug('loading %s', filepath);
        bootstrap = require(filepath);
    }
} catch (error) {
    console.dir(error);
    console.error(`${__filename.gray}: failing back to ${__dirname}/lib/bootstrap.js`);
    filepath = './lib/bootstrap';
}

/**
 * Loading from ${__dirname}/lib/bootstrap.js
 */
try {
    if (!bootstrap) {
        debug('loading %s', filepath);
        bootstrap = require(filepath);
    }
} catch (error) {
    console.dir(error);
    console.error(`${__filename.gray}: failed to load ${filepath}, and exit 1.`);
    process.exit(1);
}

module.exports = exports = bootstrap;