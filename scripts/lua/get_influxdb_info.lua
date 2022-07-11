--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local ts_utils = require("ts_utils")
local json = require "dkjson"
local checks = require("checks")
local rest_utils = require("rest_utils")

local influxdb = ts_utils.getQueryDriver()
local info = {}

if influxdb.getInfluxdbVersion then
  info.version = influxdb:getInfluxdbVersion()
  info.db_bytes = influxdb:getDiskUsage()
  info.memory = influxdb:getMemoryUsage()
  info.num_series = influxdb:getSeriesCardinality()
  info.points_exported = influxdb:get_exported_points()
  info.exports = influxdb:get_exports()
  info.health = influxdb:get_health()
end

rest_utils.answer(rest_utils.consts.success.ok, info)
