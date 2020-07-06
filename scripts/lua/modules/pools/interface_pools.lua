--
-- (C) 2017-20 - ntop.org
--

package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
local base_pools = require "base_pools"
local interface_pools = {}

-- ##############################################

function interface_pools:create()
   -- Instance of the base class
   local _interface_pools = base_pools:create()

   -- Subclass using the base class instance
   self.key = "interface"
   -- self is passed as argument so it will be set as base class metatable
   -- and this will actually make it possible to override functions
   local _interface_pools_instance = _interface_pools:create(self)

   -- Return the instance
   return _interface_pools_instance
end

-- ##############################################

-- @brief Returns a table of all possible interface ids, both assigned and unassigned to pool members
function interface_pools:get_all_members()
   local res = {}

   for ifid, ifname in pairs(interface.getIfNames()) do
      res[ifid] = {ifid = ifid, ifname = ifname}
   end

   return res
end

-- ##############################################

return interface_pools
