--
-- (C) 2017-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
local pools = require "pools"
local local_network_pools = {}

-- ##############################################

function local_network_pools:create()
   -- Instance of the base class
   local _local_network_pools = pools:create()

   -- Subclass using the base class instance
   self.key = "local_network"
   -- self is passed as argument so it will be set as base class metatable
   -- and this will actually make it possible to override functions
   local _local_network_pools_instance = _local_network_pools:create(self)

   -- Return the instance
   return _local_network_pools_instance
end

-- ##############################################

-- @brief Given a member key, returns a table of member details such as member name.
function local_network_pools:get_member_details(member)
   -- Only the name is relevant for local_networks
   local details = {local_network_id = ntop.getNetworkIdByName(member)}

   local alias = getLocalNetworkAlias(member)
   if alias ~= member then
      details["alias"] = alias
   end

   return details
end

-- ##############################################

-- @brief Returns a table of all possible local_network ids, both assigned and unassigned to pool members
function local_network_pools:get_all_members()
   local res = {}

   for local_network, _ in pairs(ntop.getNetworks()) do
      -- The key is the member id itself, which in this case is the local_network id
      res[local_network] = self:get_member_details(local_network)
   end

   return res
end

-- ##############################################

return local_network_pools
