--
-- (C) 2017-20 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local os_utils = require "os_utils"
local base_pools = require "base_pools"

-- ##############################################

local pools_lua_utils = {}

-- ##############################################

-- @brief Returns an array of pool Lua class instances, for all available pools
--        e.g., {interface_pools:create(), local_network_pools:create(), snmp_device_pools:create(), ...}
--
--        This method is useful to perform operations (such as the deletion of a configset id) which are
--        global and affect all the pool instances. Indeed a configset id is shared across all pools
local function all_pool_instances_factory()
   local pools_dir = os_utils.fixPath(dirs.installdir .. "/scripts/lua/modules/pools/")
   local res = {}

   for pool_file in pairs(ntop.readdir(pools_dir)) do
      if pool_file:match("%.lua$") then
	 local pool_file_path = os_utils.fixPath(string.format("%s/%s", pools_dir, pool_file))

	 local pool = dofile(pool_file_path)

	 -- Make sure pool is actually a pool Lua class by checking if it has method create
	 -- this is to avoid instantiating modules such as pool_lua_utils.lua and pool_rest_utils.lua
	 -- which are not classes and thus cannot be instantiated
	 if pool.create then
	    -- If it has a method create, then we can instantiate it and add it to the result
	    local instance = pool:create()
	    res[#res + 1] = instance
	 end
      end
   end

   return res
end

-- ##############################################

-- @brief Call `instance:unbind_all_configset_id` for every available pools `instance`
function pools_lua_utils.unbind_all_configset_id(configset_id)
   local all_instances = all_pool_instances_factory()

   for _, instance in pairs(all_instances) do
      instance:unbind_all_configset_id(configset_id)
   end
end

-- ##############################################

-- @brief Call `instance:unbind_all_configset_id` for every available pools `instance`
function pools_lua_utils.unbind_all_recipient_id(recipient_id)
   local all_instances = all_pool_instances_factory()

   for _, instance in pairs(all_instances) do
      instance:unbind_all_recipient_id(recipient_id)
   end
end

-- ##############################################

return pools_lua_utils
