--
-- (C) 2013-17 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local callback_utils = require "callback_utils"
local discover_utils = require "discover_utils"

local discovery_enabled = (ntop.getPref("ntopng.prefs.is_network_discovery_enabled") == "1")
local ifnames = interface.getIfNames()

local requests = false
callback_utils.foreachInterface(ifnames, nil, function(ifname, ifstats)
   if discover_utils.networkDiscoveryRequested(ifstats.id) then
      requests = true
   end
end)

if discovery_enabled or requests then

   local now = os.time()
   local discovery_interval = ntop.getPref("ntopng.prefs.network_discovery_interval")
   if isEmptyString(discovery_interval) then discovery_interval = 15 * 60 end

   local diff = now % tonumber(discovery_interval)

   if diff < 60 then
      callback_utils.foreachInterface(ifnames, nil, function(ifname, ifstats)
         if interface.isDiscoverableInterface() and discover_utils.interfaceNetworkDiscoveryEnabled(ifstats.id) then
	    local res

	    ntop.traceEvent("[Discover] Started periodic discovery on interface "..ifname.."\n")
	    res = discover_utils.discover2table(ifname, true --[[ recache --]])
	    ntop.traceEvent("[Discover] Completed periodic discovery on interface "..ifname.."\n")
	    discover_utils.clearNetworkDiscovery(ifstats.id)
	 end
      end)

   elseif requests then
      callback_utils.foreachInterface(ifnames, nil, function(ifname, ifstats)
         if discover_utils.networkDiscoveryRequested(ifstats.id) then
	    local res

	    ntop.traceEvent("[Discover] Started triggered discovery on interface "..ifname.."\n")
	    res = discover_utils.discover2table(ifname, true --[[ recache --]])
	    ntop.traceEvent("[Discover] Completed triggered discovery on interface "..ifname.."\n")
	    discover_utils.clearNetworkDiscovery(ifstats.id)
	 end

      end)
   end
end
