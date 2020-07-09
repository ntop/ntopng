--
-- (C) 2017-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils" -- needed by am_utils
local plugins_utils = require "plugins_utils"
local am_utils = plugins_utils.loadModule("active_monitoring", "am_utils")
local base_pools = require "base_pools"

local active_monitoring_pools = {}

-- ##############################################

function active_monitoring_pools:create()
   -- Instance of the base class
   local _active_monitoring_pools = base_pools:create()

   -- Subclass using the base class instance
   self.key = "active_monitoring"
   -- self is passed as argument so it will be set as base class metatable
   -- and this will actually make it possible to override functions
   local _active_monitoring_pools_instance = _active_monitoring_pools:create(self)

   -- Return the instance
   return _active_monitoring_pools_instance
end

-- ##############################################

-- @brief Given a member key, returns a table of member details such as member name.
function active_monitoring_pools:get_member_details(member)
   local name = member
   local am_host = am_utils.key2host(member)

   if am_host and am_host["label"] then
      name = am_host["label"]
   end

   return {name = name}
end

-- ##############################################

-- @brief Returns a table of all possible active_monitoring ids, both assigned and unassigned to pool members
function active_monitoring_pools:get_all_members()
   local res = {}

   local am_hosts = am_utils.getHosts()
   for key, _ in pairs(am_hosts) do
      -- The key is the member id itself, which in this case is the active_monitoring id
      res[key] = self:get_member_details(key)
   end

   return res
end

-- ##############################################

return active_monitoring_pools
