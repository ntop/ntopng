--
-- (C) 2013-22 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local discover_utils = require "discover_utils"
local callback_utils = require "callback_utils"

-- ########################################################

local ifnames = interface.getIfNames()

-- ########################################################

local periodic_discovery_condition = function(ifId)
   return discover_utils.interfaceNetworkDiscoveryEnabled(ifId)
end

-- ########################################################

local oneshot_discovery_condition = function(ifId)
   return discover_utils.networkDiscoveryRequested(ifId)
end

-- ########################################################

local discovery_function = function(ifname, ifstats)
   if interface.isDiscoverableInterface() then
      traceError(TRACE_INFO,TRACE_CONSOLE, "[Discover] Started periodic discovery on interface "..ifname)

      local res = discover_utils.discover2table(ifname, true --[[ recache --]])

      traceError(TRACE_INFO,TRACE_CONSOLE, "[Discover] Completed periodic discovery on interface "..ifname)
      discover_utils.clearNetworkDiscovery(ifstats.id)
   end
end

-- ########################################################

-- periodic discovery enabled
local discovery_enabled = (ntop.getPref("ntopng.prefs.is_periodic_network_discovery_enabled") == "1")
local discovery_interval = ntop.getPref("ntopng.prefs.network_discovery_interval")

-- Run this script for a minute before quitting (this reduces load on Lua VM infrastructure)
local num_runs = 12

for i=1,num_runs do
   if(ntop.isShutdown()) then break end

   if discovery_enabled then  
      if isEmptyString(discovery_interval) then discovery_interval = 15 * 60 --[[ 15 minutes --]] end

      local now = os.time()
      local diff = now % tonumber(discovery_interval)
      
      if diff < 5 then
         ntop.setPref("ntopng.prefs.is_periodic_network_discovery_running", "1")
	      callback_utils.foreachInterface(ifnames, periodic_discovery_condition, discovery_function)
         ntop.setPref("ntopng.prefs.is_periodic_network_discovery_running", "0")
      end
   end
   
   -- discovery requests performed by the user from the GUI
   callback_utils.foreachInterface(ifnames, oneshot_discovery_condition, discovery_function)
   
   ntop.msleep(5000) -- 5 seconds frequency
end
