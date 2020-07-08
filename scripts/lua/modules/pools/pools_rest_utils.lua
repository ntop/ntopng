--
-- (C) 2017-20 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local base_pools = require "base_pools"

-- ##############################################

local pools_rest_utils = {}

-- ##############################################

-- @brief Add a pool
function pools_rest_utils.add_pool(pools)   
   local name = _POST["pool_name"]
   local members = _POST["pool_members"]
   local confset_id = _POST["confset_id"]

   sendHTTPHeader('application/json')

   if not isAdministrator() then
      print(rest_utils.rc(rest_utils.consts_not_granted))
      return
   end

   if not name or not members or not confset_id then
      print(rest_utils.rc(rest_utils.consts_invalid_args))
      return
   end

   -- Create an instance out of the `pools` passed as argument
   local s = pools:create()

   members = s:parse_members(members)
   -- confset_id as number
   confset_id = tonumber(confset_id)

   local new_pool_id = s:add_pool(name, members --[[ an array of valid interface ids]], confset_id --[[ a valid configset_id --]])

   if not new_pool_id then
      print(rest_utils.rc(rest_utils.consts_add_pool_failed))
      return
   end

   local rc = rest_utils.consts_ok
   local res = {
      pool_id = new_pool_id
   }

   print(rest_utils.rc(rc, res))
end

-- ##############################################

-- @brief Edit a pool
function pools_rest_utils.edit_pool(pools)
   local pool_id = _POST["pool"]
   local name = _POST["pool_name"]
   local members = _POST["pool_members"]
   local confset_id = _POST["confset_id"]

   sendHTTPHeader('application/json')

   if not isAdministrator() then
      print(rest_utils.rc(rest_utils.consts_not_granted))
      return
   end

   if not pool_id or not name or not members or not confset_id then
      print(rest_utils.rc(rest_utils.consts_invalid_args))
      return
   end

   -- Create the instance
   local s = pools:create()

   members = s:parse_members(members)
   -- pool_id as number
   pool_id = tonumber(pool_id)
   -- confset_id as number
   confset_id = tonumber(confset_id)


   local res = s:edit_pool(pool_id, name, members --[[ an array of valid interface ids]], confset_id --[[ a valid configset_id --]])

   if not res then
      print(rest_utils.rc(rest_utils.consts_edit_pool_failed))
      return
   end

   local rc = rest_utils.consts_ok
   print(rest_utils.rc(rc))

end

-- ##############################################

-- @brief Delete a pool
function pools_rest_utils.delete_pool(pools)
   local pool_id = _POST["pool"]

   sendHTTPHeader('application/json')

   if not isAdministrator() then
      print(rest_utils.rc(rest_utils.consts_not_granted))
      return
   end

   if not pool_id then
      print(rest_utils.rc(rest_utils.consts_invalid_args))
      return
   end

   -- pool_id as number
   pool_id = tonumber(pool_id)

   -- Create the instance
   local s = pools:create()
   local res = s:delete_pool(pool_id)

   if not res then
      print(rest_utils.rc(rest_utils.consts_pool_not_found))
      return
   end

   local rc = rest_utils.consts_ok
   local res = {
      pool_id = new_pool_id
   }

   print(rest_utils.rc(rc, res))
end

-- ##############################################

-- @brief Get one or all pools
function pools_rest_utils.get_pools(pools)
   local pool_id = _GET["pool"]

   sendHTTPHeader('application/json')

   -- pool_id as number
   pool_id = tonumber(pool_id)

   local res = {}

   -- Create the instance
   local s = pools:create()

   if pool_id then
      -- Return only one pool
      local cur_pool = s:get_pool(pool_id)

      if cur_pool then
	 res[pool_id] = cur_pool
      else
	 print(rest_utils.rc(rest_utils.consts_pool_not_found))
	 return
      end
   else
      -- Return all pool ids
      res = s:get_all_pools()
   end

   local rc = rest_utils.consts_ok
   print(rest_utils.rc(rc, res))

end

-- ##############################################

return pools_rest_utils
