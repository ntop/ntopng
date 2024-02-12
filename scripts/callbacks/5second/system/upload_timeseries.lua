--
-- (C) 2013-24 - ntop.org
--
-- This script is used to timeseries-related periodic activities
-- for example to send data to a remote timeseries collector

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local influxdb_export_api = require "influxdb_export_api"

if influxdb_export_api.isInfluxdbEnabled() then
   local callback_utils = require "callback_utils"
   
   local debug = false
   if(debug) then io.write("[upload_timeseries.lua] Uploading...\n") end
   callback_utils.uploadTSdata()
   if(debug) then io.write("[upload_timeseries.lua] Upload completed: sleeping...\n") end
end
