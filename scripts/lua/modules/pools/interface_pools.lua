--
-- (C) 2017-20 - ntop.org
--

package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
local base_pools = require "base_pools"
local interface_pools = {}

-- ##############################################

function interface_pools:create(name, members, configset_id)
   -- Instance of the base class
   local _interface_pools = base_pools:create()
   -- Subclass using the base class instance
   local _interface_pools_instance = _interface_pools:create({key = "interface", name = name or '', members = members or {}, configset_id = configset_id or 0})

   -- In the instance has been created successfully, we can persist it
   if _interface_pools_instance then
      if not _interface_pools_instance:_persist() then
	 -- Failed to persist the instance, unable to create
	 return nil
      end
   end

   -- Return the instance
   return _interface_pools_instance
end

-- ##############################################

-- @brief Returns members which doesn't belong to any pool
function interface_pools.list_available_members()
   -- STUB: currently returns all members
   local res = {}

   for ifid, ifname in pairs(interface.getIfNames()) do
      res[#res + 1] = {id = ifid, name = ifname}
   end

   return res
end

-- ##############################################

-- @brief Returns available confset ids which can be added to a pool
function interface_pools.list_available_configset_ids()
   -- Just call the function in base_pools, see if it can be done with inheritance
   return base_pools.list_available_configset_ids()
end

-- ##############################################

return interface_pools
