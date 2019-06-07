--
-- (C) 2018 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local ts_utils = require("ts_utils")
local json = require "dkjson"

local driver = ts_utils.getQueryDriver()

local info = {}

if driver.getInfluxdbVersion then
  info.version = driver:getInfluxdbVersion()
  info.db_bytes = driver:getDiskUsage()
  info.memory = driver:getMemoryUsage()
  info.num_series = driver:getSeriesCardinality()
end

sendHTTPContentTypeHeader('application/json')
print(json.encode(info))
