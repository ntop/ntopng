--
-- (C) 2013-26 - ntop.org
--
-- This script is used to timeseries-related periodic activities
-- for example to send data to a remote timeseries collector
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local callback_utils = require "callback_utils"
local scripts_triggers = require "scripts_triggers"

local ifnames = interface.getIfNames()

-- ###########################################

local function interface_creation_enabled(ifid)
   return (true)
end

-- ###########################################

local traceme = false

while(not(ntop.isShuttingDown())) do
   -- Note: foreachInterface calls interface.select() for each interface
   callback_utils.foreachInterface(ifnames, interface_creation_enabled,
				   function(ifname, ifstats)
				      if(traceme) then io.write("Processing " .. ifname .. " ifid: " .. ifstats.id .. "\n") end

				      -- Export/flush timeseries data
				      callback_utils.uploadTSdata(0) -- 0 = no deadline)
				   end, true)


   if(traceme) then io.write("Processing system interface\n") end

   -- Update system interface
   interface.select(-1)
   callback_utils.uploadTSdata(0) -- 0 = no deadline)

   ntop.msleep(1000) -- 1 second
end
