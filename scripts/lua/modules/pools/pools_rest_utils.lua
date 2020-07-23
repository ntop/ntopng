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
   local recipients = _POST["recipients"]

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
   recipients = s:parse_recipients(recipients)
   -- confset_id as number
   confset_id = tonumber(confset_id)

   local new_pool_id = s:add_pool(
      name,
      members --[[ an array of valid interface ids]],
      confset_id --[[ a valid configset_id --]],
      recipients --[[ an array of valid recipient ids (names)]]
   )

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
   local recipients = _POST["pool_recipients"]

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
   recipients = s:parse_recipients(recipients)
   -- pool_id as number
   pool_id = tonumber(pool_id)
   -- confset_id as number
   confset_id = tonumber(confset_id)

   local res = s:edit_pool(pool_id,
      name,
      members --[[ an array of valid interface ids]], 
      confset_id --[[ a valid configset_id --]],
      recipients --[[ an array of valid recipient ids (names)]]
   )

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

-- @brief Bind a member to a pool
function pools_rest_utils.bind_member(pools)
   local pool_id = _GET["pool"]
   local member = _POST["member"]

   sendHTTPHeader('application/json')

   if not isAdministrator() then
      print(rest_utils.rc(rest_utils.consts_not_granted))
      return
   end

   if not pool_id or not member then
      print(rest_utils.rc(rest_utils.consts_invalid_args))
      return
   end

   -- pool_id as number
   pool_id = tonumber(pool_id)

   -- Create the instance
   local s = pools:create()
   local res, err

   if pool_id == s.DEFAULT_POOL_ID then
      -- Always bind the member to the default pool id (possibly removing it from any other pool)
      res, err = s:bind_member(member, pool_id)
   else
      -- Bind the member only if it is not already in another pool
      res, err = s:bind_member_if_not_already_bound(member, pool_id)
   end

   if not res then
      if err == base_pools.ERRORS.ALREADY_BOUND then
	 -- Member already existing, return current pool information in the response
	 local cur_pool = s:get_pool_by_member(member)
	 print(rest_utils.rc(rest_utils.consts_bind_pool_member_already_bound, cur_pool))
      else
	 -- Generic
	 print(rest_utils.rc(rest_utils.consts_bind_pool_member_failed))
      end

      return
   end

   local rc = rest_utils.consts_ok
   print(rest_utils.rc(rc))
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

-- @brief Get one or all pools
function pools_rest_utils.get_pool_members(pools)
   local pool_id = _GET["pool"]

   sendHTTPHeader('application/json')

   -- pool_id as number
   pool_id = tonumber(pool_id)

   local res = {}

   -- Create the instance
   local s = pools:create()

   local cur_pool = s:get_pool(pool_id)

   if not cur_pool then
      print(rest_utils.rc(rest_utils.consts_pool_not_found))
      return
   end

   for member, details in pairs(cur_pool["member_details"]) do
      details["member"] = member
      res[#res + 1] = details
   end

   local rc = rest_utils.consts_ok
   print(rest_utils.rc(rc, res))
end

-- ##############################################

-- @brief Get one or all pools
function pools_rest_utils.get_pool_by_member(pools)
   local member = _POST["member"]

   sendHTTPHeader('application/json')

   if not member then
      print(rest_utils.rc(rest_utils.consts_invalid_args))
      return
   end

   local res = {}

   -- Create the instance
   local s = pools:create()
   local cur_pool = s:get_pool_by_member(member)
   if cur_pool then
      res = cur_pool
   end

   local rc = rest_utils.consts_ok
   print(rest_utils.rc(rc, res))
end

-- ##############################################

return pools_rest_utils
