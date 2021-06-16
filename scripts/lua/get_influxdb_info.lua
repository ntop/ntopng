--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local ts_utils = require("ts_utils")
local json = require "dkjson"
local checks = require("checks")

local driver = ts_utils.getQueryDriver()
local probe = checks.loadModule(getSystemInterfaceId(), checks.script_types.system, "system", "influxdb_monitor")

local info = {}

if driver.getInfluxdbVersion then
  info.version = driver:getInfluxdbVersion()
  info.db_bytes = driver:getDiskUsage()
  info.memory = driver:getMemoryUsage()
  info.num_series = driver:getSeriesCardinality()

  if(probe ~= nil) then
    local stats = probe.getExportStats()
    info.points_exported = stats.points_exported
    info.points_dropped = stats.points_dropped
    info.exports = stats.exports
    info.health = stats.health
  end
end

sendHTTPContentTypeHeader('application/json')
print(json.encode(info))
