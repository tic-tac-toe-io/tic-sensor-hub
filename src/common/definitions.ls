#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#


##
# Event Prototype: (profile, id, items, context)
#
# `profile` , profile
#
# `id`      , the unique identity for the TOE device
#
# `items`   , the array of data items measured by TOE1 devices, Each data item has following structure
#   - desc
#     - board_type
#     - board_id
#     - sensor
#     - data_type
#   - data
#     - updated_at
#     - value
#     - type
#     - unit_length
#
# `context` , the extra information to describe these measurement data items.
#   - source: toe1-upload, toe3-upload, tic3-api
#   - upload
#     - filename, the `originalname` in HTTP Form for archive upload
#     - compressed-size, the size of json.gz in bytes
#     - raw-size, the size of json in bytes
#   - timestamps
#     - measured, the timestamp when the data points are measured at TOE device (or TIC api calls)
#     - received, the timestamp when the archive is received at cloud
#
const APPEVT_TIME_SERIES_V1_DATA_POINTS = \ts::v1::points


##
# Event Prototype: (profile, id, measurements, context)
#
# `profile`       , profile
#
# `id`            , the unique identity for the TOE device
#
# `measurements`  , the array of measured data points. each measurement point shall be an object
#   - epoch, timestamp when the point is measured
#   - p_type
#   - p_id
#   - s_type
#   - s_id
#   - field_sets, all field key-value pairs for the point
#   For performance considerations, above object attributes are packed in an array:
#     [p_type, p_id, s_type, s_id, field_sets]
#
# `context`       , the extra information to describe these measurement data items.
#   - source: toe1-upload, toe3-upload, tic3-api
#   - upload
#     - filename, the `originalname` in HTTP Form for archive upload
#     - compressed-size, the size of json.gz in bytes
#     - raw-size, the size of json in bytes
#   - timestamps
#     - measured, the timestamp when the data points are measured at TOE device or TIC api calls (mandatory)
#     - received, the timestamp when the data items are arrived at cloud (mandatory)
#     - transformed, the timestamp when the data items are transformed to v3 schema (optional)
#
const APPEVT_TIME_SERIES_V3_MEASUREMENTS = \ts::v3::measurements


const WEBAPI_UPLOAD_ARCHIVE_MULTIPART_FIELD = \sensor_data_gz


const THE_END = \END


const constants = {
  APPEVT_TIME_SERIES_V1_DATA_POINTS,
  APPEVT_TIME_SERIES_V3_MEASUREMENTS,

  WEBAPI_UPLOAD_ARCHIVE_MULTIPART_FIELD,

  THE_END
}

module.exports = exports = {constants}