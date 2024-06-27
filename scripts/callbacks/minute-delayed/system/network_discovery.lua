--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local discover_utils = require "discover_utils"

-- ########################################################

if(ntop.limitResourcesUsage()) then return end

-- ########################################################

local ifnames = interface.getIfNames()

-- ########################################################

local periodic_discovery_condition = function(ifId)
   return discover_utils.interfaceNetworkDiscoveryEnabled(ifId)
end

-- ########################################################

-- periodic discovery enabled
local discovery_enabled = (ntop.getPref("ntopng.prefs.is_periodic_network_discovery_enabled") == "1")

-- Run this script for a minute before quitting (this reduces load on Lua VM infrastructure)
local num_runs = 12

if discovery_enabled then 
   local now = os.time()

   local last_discovery = ntop.getCache("ntopng.cache.network_discovery.last")
   if isEmptyString(last_discovery) then
      last_discovery = 0
   else
      last_discovery = tonumber(last_discovery)
   end

   local discovery_interval = ntop.getPref("ntopng.prefs.network_discovery_interval")
   if isEmptyString(discovery_interval) then
      discovery_interval = 15 * 60 --[[ 15 minutes --]]
   else
      discovery_interval = tonumber(discovery_interval)
   end

   if now >= last_discovery + discovery_interval then
      local callback_utils = require "callback_utils"
      ntop.setCache("ntopng.cache.network_discovery.last", tostring(now))

      callback_utils.foreachInterface(ifnames, periodic_discovery_condition, discover_utils.discovery_function)
   end
end
