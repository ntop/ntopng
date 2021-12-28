--
-- (C) 2013-21 - ntop.org
--
-- This script is used to timeseries-related periodic activities
-- for example to send data to a remote timeseries collector

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local callback_utils = require "callback_utils"

-- Run this script for a minute before quitting (this reduces load on Lua VM infrastructure)
local num_runs = 1
local debug = false

for i=1,num_runs do
   if(ntop.isShutdown()) then break end

   local now = os.time()
   if(debug) then io.write("[influxdb.lua] Uploading...\n") end
   callback_utils.uploadTSdata()
   if(debug) then io.write("[influxdb.lua] Upload completed: sleeping...\n") end

   if(num_runs > 1) then
      ntop.msleep(1000)
      if(debug) then io.write("[influxdb.lua] Sleep over\n") end
   end
end
