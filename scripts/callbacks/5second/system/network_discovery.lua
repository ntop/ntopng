--
-- (C) 2013-23 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local discover_utils = require "discover_utils"
local callback_utils = require "callback_utils"

-- ########################################################

if(ntop.limitResourcesUsage()) then return end

-- ########################################################

local ifnames = interface.getIfNames()

-- ########################################################

local oneshot_discovery_condition = function(ifId)
   local check_requested = discover_utils.networkDiscoveryRequested(ifId)
   return check_requested
end

-- ########################################################

-- discovery requests performed by the user from the GUI
callback_utils.foreachInterface(ifnames, oneshot_discovery_condition, discover_utils.discovery_function)

