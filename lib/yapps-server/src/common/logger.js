/**
 * Copyright (c) 2019-2025 T2T Inc. All rights reserved
 * 
 *  https://www.t2t.io
 *  https://tic-tac-toe.io
 * 
 * Taipei, Taiwan
 */
'use strict';

const path = require('node:path');
const { promises: fs } = require("fs");
const { setTimeout: sleep } = require('timers/promises');

const pino = require('pino');
const pretty = require('pino-pretty');


const FormatMessage = (log, messageKey) => {
  let { category } = log
  let message = log[messageKey]
  if (category) {
    return `[${category.gray}]: ${message}`;
  }
  else {
    return message;
  }
}


const InitLogger = (verbose) => {
  let level = 'info';
  if (verbose) {
    level = 'debug';
  }
  let stream = pretty({
    translateTime: 'mm-dd HH:MM:ss.l',
    ignore: 'pid,hostname',
    sync: true,
    hideObject: true,
    messageFormat: FormatMessage
  });
  let logger = pino({ level }, stream);
  return logger;
}


const GET_LOGGER = (filepath = null) => {
  if (!filepath) {
    return { logger: module.logger };
  }
  let { index, environment } = module;
  let { process_name, app_dir } = environment;
  let dir = path.dirname(path.dirname(__dirname));
  let exdir = `${app_dir}/lib/yapps-server/src`
  let source_type = 'NONE';
  let source_type_color = null;
  let filename = filepath;
  if (filepath.startsWith(exdir)) {
    source_type = "yapps-server";
    source_type_color = 'blue';
    filename = filepath.substring(exdir.length);
  } else if (filepath.startsWith(app_dir)) {
    source_type = "--app--";
    source_type_color = 'green';
    filename = filepath.substring(app_dir.length);
  } else if (filepath.startsWith(dir)) {
    source_type = "yapps-server";
    source_type_color = 'blue';
    filename = filepath.substring(dir.length);
  }
  source_type = source_type.padEnd(14, ' ');
  source_type = source_type_color ? source_type[source_type_color] : source_type;
  filename = filename.padEnd(32, ' ').gray;
  process_name = process_name == 'mst' ? process_name.red : process_name.cyan;
  let tokens = [process_name, source_type, filename];
  let category = tokens.join(':');
  let logger = module.logger.child({ category });
  return {
    logger,
    DBG: (...args) => logger.debug(...args),
    ERR: (...args) => logger.error(...args),
    WARN: (...args) => logger.warn(...args),
    INFO: (...args) => logger.info(...args),
  };
}


function init(index, environment, configs, prefixers, stringifiers, callback) {
  // skip prefixers and stringifiers, that are only used for bunyan logger
  let { app_name, process_name, app_dir, work_dir, logs_dir, startup_time, verbose } = environment
  console.log(`logger.init(${index}, ${app_name}, ${process_name}, ${app_dir}, ${work_dir}, ${logs_dir}, ${startup_time}), verbose = ${verbose}`);
  module.logger = InitLogger(verbose);
  module.environment = environment;
  module.app_name = app_name;
  module.process_name = process_name;
  module.app_dir = app_dir;
  module.work_dir = work_dir;
  module.logs_dir = logs_dir;
  module.startup_time = startup_time;
  module.index = index;
  return callback(null, GET_LOGGER);
}

module.exports = exports = { init };
