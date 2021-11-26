--
-- (C) 2013-21 - ntop.org
--
-- This script is used to timeseries-related periodic activities
-- for example to send data to a remote timeseries collector

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local callback_utils = require "callback_utils"

-- Run this script for a minute before quittin (this reduces load on Lua VM infrastructure)
local num_runs = 60

for i=1,num_runs do
   if(ntop.isShutdown()) then break end

   local now = os.time()
   callback_utils.uploadTSdata()

   ntop.msleep(1000)
end
