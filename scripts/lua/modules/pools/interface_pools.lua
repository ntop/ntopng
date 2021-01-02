--
-- (C) 2017-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
local pools = require "pools"
local interface_pools = {}

-- ##############################################

function interface_pools:create()
   -- Instance of the base class
   local _interface_pools = pools:create()

   -- Subclass using the base class instance
   self.key = "interface"
   -- self is passed as argument so it will be set as base class metatable
   -- and this will actually make it possible to override functions
   local _interface_pools_instance = _interface_pools:create(self)

   -- Return the instance
   return _interface_pools_instance
end

-- ##############################################

-- @brief Given a member key, returns a table of member details such as member name.
function interface_pools:get_member_details(member)
   -- Only the name is relevant for interfaces
   return {name = getInterfaceName(member)}
end

-- ##############################################

-- @brief Returns a table of all possible interface ids, both assigned and unassigned to pool members
function interface_pools:get_all_members()
   local res = {}

   for ifid, ifname in pairs(interface.getIfNames()) do
      -- The key is the member id itself, which in this case is the interface id
      res[ifid] = self:get_member_details(ifid)
   end

   return res
end

-- ##############################################

return interface_pools
