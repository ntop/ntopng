--
-- (C) 2013-17 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local discovery_enabled = (ntop.getPref("ntopng.prefs.is_network_discovery_enabled") == "1")

if discovery_enabled then
   require "lua_utils"
   local discover_utils = require "discover_utils"
   local callback_utils = require "callback_utils"

   local now = os.time()
   local discovery_interval = ntop.getPref("ntopng.prefs.network_discovery_interval")
   if isEmptyString(discovery_interval) then discovery_interval = 15 * 60 end

   local diff = now % tonumber(discovery_interval)
	  
   if diff < 60 then
      local ifnames = interface.getIfNames()

      callback_utils.foreachInterface(ifnames, nil, function(ifname, ifstats)
         if interface.isDiscoverableInterface() then
	    local res = discover_utils.discover2table(ifname, true --[[ recache --]])
	 end

      end)

   end
end
