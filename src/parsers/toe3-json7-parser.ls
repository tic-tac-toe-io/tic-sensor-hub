#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#

require! <[lodash]>
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename
{Dictionary, TagSet, FieldSet, Measurement, IndexingList} = require \./utils


TIMESTAMP_ARGS_TO_OBJECT = (x) ->
  [uptime, epoch, purpose] = x
  return {uptime, epoch, purpose}


GET_TIMESTAMP_ANCHOR = (timestamps) ->
  anchor = lodash.find timestamps, {purpose: "archive_end"}
  return anchor if anchor?
  anchor = lodash.find timestamps, {purpose: "archive_start"}
  return anchor if anchor?
  return timestamps[0]

MSG_WITH_ZERO = (message) ->
  INFO message
  return 0


class Parser
  (@opts) ->
    return

  parse-tagsets: (xs) ->
    {dictionary, ts-list} = self = @
    for indexes in xs
      ts = new TagSet dictionary
      ts.load.apply ts, indexes
      ts-list.add ts


  parse-fieldsets: (xs) ->
    {dictionary, fs-list} = self = @
    for indexes in xs
      fs = new FieldSet dictionary
      fs.load indexes
      fs-list.add fs


  calculate-time-delta: (boots, epoch-anchor, global-anchor=null) ->
    {id} = self = @
    # DBG "boots: #{boots}"
    # DBG "epoch-anchor: #{JSON.stringify epoch-anchor}"
    # DBG "global-anchor: #{JSON.stringify global-anchor}"
    return MSG_WITH_ZERO "[#{id}] missing boots" unless boots? and boots > 0
    return MSG_WITH_ZERO "[#{id}] missing global-anchor" unless global-anchor?
    return MSG_WITH_ZERO "[#{id}] missing global-anchor.boots" unless global-anchor.boots? and global-anchor.boots > 0
    return MSG_WITH_ZERO "[#{id}] missing global-anchor.uptime" unless global-anchor.uptime? and global-anchor.uptime > 0
    return MSG_WITH_ZERO "[#{id}] missing epoch-anchor.uptime" unless epoch-anchor.uptime?
    return MSG_WITH_ZERO "[#{id}] global-anchor.boots != boots" unless global-anchor.boots is boots
    return MSG_WITH_ZERO "[#{id}] global-anchor.uptime (#{global-anchor.uptime}) < archive's last uptime (#{epoch-anchor.uptime})" unless global-anchor.uptime >= epoch-anchor.uptime
    return MSG_WITH_ZERO "[#{id}] missing global-anchor.epoch" unless global-anchor.epoch? and global-anchor.epoch > 0
    return MSG_WITH_ZERO "[#{id}] missing global-anchor.now" unless global-anchor.now? and global-anchor.now > 0
    delta = global-anchor.now - global-anchor.epoch
    return MSG_WITH_ZERO "[#{id}] calibration < 10s" unless (Math.abs delta) > 10s * 1000ms
    INFO "#{id}: needs time calibration => #{delta}ms (local: #{global-anchor.epoch}, global: #{global-anchor.now})"
    return delta


  parse-measurements: (xs, uptime-anchor, epoch-anchor, boots, global-anchor) ->
    {measurements, ts-list, fs-list} = self = @
    global-time-delta = self.calculate-time-delta boots, epoch-anchor, global-anchor
    for indexes in xs
      [uptime, ts-index, fs-index, vs] = indexes
      ts = ts-list.get ts-index
      fs = fs-list.get fs-index
      # epoch = uptime + uptime-anchor.epoch
      uptime = uptime + uptime-anchor.uptime
      epoch = epoch-anchor.epoch - (epoch-anchor.uptime - uptime) + global-time-delta
      timestamp = {uptime, epoch}
      m = new Measurement timestamp, ts, fs, vs
      measurements.push m


  parse: (json, global-anchor) ->
    self = @
    {metadata, data} = json
    {id} = metadata
    {compaction, parameters, points} = data
    {time} = parameters
    {base, boots} = time
    timestamps = [ TIMESTAMP_ARGS_TO_OBJECT t for t in time.timestamps ]
    uptime-anchor = lodash.find timestamps, {purpose: "archive_start"}
    epoch-anchor = GET_TIMESTAMP_ANCHOR timestamps
    self.id = id
    self.dictionary = new Dictionary {}
    self.dictionary.load parameters.dictionary
    self.ts-list = new IndexingList {}
    self.fs-list = new IndexingList {}
    self.parse-tagsets parameters.tag_sets
    self.parse-fieldsets parameters.field_sets
    self.measurements = []
    self.parse-measurements points, uptime-anchor, epoch-anchor, boots, global-anchor


  to-ttt: (array=no) ->
    {measurements} = self = @
    xs = [ (m.to-sensor-event-object array) for m in measurements ]
    return xs


module.exports = exports = Parser