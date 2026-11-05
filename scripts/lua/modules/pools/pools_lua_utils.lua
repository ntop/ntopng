--
-- (C) 2017-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

-- require "lua_utils"
local json = require "dkjson"
local os_utils = require "os_utils"

-- ##############################################

local pools_lua_utils = {}

-- ##############################################

-- @brief Returns an array of pool Lua class instances, for all available pools
function pools_lua_utils.all_pool_instances_factory()
   local pools_dir = os_utils.fixPath(dirs.installdir .. "/scripts/lua/modules/pools/")
   local res = {}

   for pool_file in pairs(ntop.readdir(pools_dir)) do
      -- Load all sub-classes of pools.lua (and exclude pools.lua itself)
      if pool_file:match("_pools%.lua$") and not pool_file:match("^pools.lua$") then
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

-- @brief Returns the url of the pools list
-- @param pool_key A pool key string as found inside `create` method of any pools instance
--                 (unused: the host pools are the only pools left)
-- @return The pool url
function pools_lua_utils.get_pool_url(pool_key)
   return ntop.getHttpPrefix().."/lua/pool_stats.lua"
end

-- ##############################################

return pools_lua_utils
