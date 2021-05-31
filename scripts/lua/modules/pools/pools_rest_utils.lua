--
-- (C) 2017-21 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local pools = require "pools"
local pools_lua_utils = require "pools_lua_utils"
local tracker = require("tracker")
local auth = require "auth"

-- ##############################################

local pools_rest_utils = {}

-- ##############################################

-- @brief Add a pool
function pools_rest_utils.add_pool(pools)
   local name = _POST["pool_name"]
   local members = _POST["pool_members"]
   local recipients = _POST["recipients"]

   if not auth.has_capability(auth.capabilities.pools) then
      rest_utils.answer(rest_utils.consts.err.not_granted)
      return
   end

   if not name or not members then
      rest_utils.answer(rest_utils.consts.err.invalid_args)
      return
   end

   -- Create an instance out of the `pools` passed as argument
   local s = pools:create()

   members_list = s:parse_members(members)
   recipients = s:parse_recipients(recipients)

   local new_pool_id = s:add_pool(
      name,
      members_list --[[ an array of valid interface ids]],
      recipients --[[ an array of valid recipient ids (names)]]
   )

   if not new_pool_id then
      rest_utils.answer(rest_utils.consts.err.add_pool_failed)
      return
   end

   local rc = rest_utils.consts.success.pool_added
   local res = {
      pool_id = new_pool_id
   }

   rest_utils.answer(rc, res)

   -- TRACKER HOOK
   tracker.log('add_pool', { pool_name = name, members = members, pool_key = s.key })
end

-- ##############################################

-- @brief Edit a pool
function pools_rest_utils.edit_pool(pools)
   local pool_id = _POST["pool"]
   local name = _POST["pool_name"]
   local members = _POST["pool_members"]
   local recipients = _POST["recipients"]

   if not auth.has_capability(auth.capabilities.pools) then
      rest_utils.answer(rest_utils.consts.err.not_granted)
      return
   end

   if not pool_id or not name or not members then
      rest_utils.answer(rest_utils.consts.err.invalid_args)
      return
   end

   -- Create the instance
   local s = pools:create()

   members_list = s:parse_members(members)
   recipients = s:parse_recipients(recipients)
   -- pool_id as number
   pool_id = tonumber(pool_id)

   local res = s:edit_pool(pool_id,
      name,
      members_list --[[ an array of valid interface ids]], 
      recipients --[[ an array of valid recipient ids (names)]]
   )

   if not res then
      rest_utils.answer(rest_utils.consts.err.edit_pool_failed)
      return
   end

   local rc = rest_utils.consts.success.pool_edited
   rest_utils.answer(rc)

   -- TRACKER HOOK
   tracker.log('edit_pool', { pool_id = pool_id, pool_name = name, members = members, pool_key = s.key })
end

-- ##############################################

-- @brief Delete a pool
function pools_rest_utils.delete_pool(pools)
   local pool_id = _POST["pool"]

   if not auth.has_capability(auth.capabilities.pools) then
      rest_utils.answer(rest_utils.consts.err.not_granted)
      return
   end

   if not pool_id then
      rest_utils.answer(rest_utils.consts.err.invalid_args)
      return
   end

   -- pool_id as number
   pool_id = tonumber(pool_id)

   -- Create the instance
   local s = pools:create()

   -- Fetch the existing pool
   local existing_pool = s:get_pool(pool_id)
   if not existing_pool then
      rest_utils.answer(rest_utils.consts.err.pool_not_found)
      return
   end

   -- Delete the pool
   local res = s:delete_pool(pool_id)
   if not res then
      rest_utils.answer(rest_utils.consts.err.pool_not_found)
      return
   end

   local rc = rest_utils.consts.success.pool_deleted
   local res = {
      pool_id = new_pool_id
   }

   rest_utils.answer(rc, res)

   -- TRACKER HOOK
   tracker.log('delete_pool', { pool_id = pool_id,  pool_name = existing_pool["name"], pool_key = s.key })
end

-- ##############################################

-- @brief Bind a member to a pool
function pools_rest_utils.bind_member(pools)
   local old_pool_name = _GET["pool_name"]
   local pool_id = _GET["pool"]
   local member = _POST["member"]

   if not isAdministrator() then
      rest_utils.answer(rest_utils.consts.err.not_granted)
      return
   end

   if not pool_id or not member then
      rest_utils.answer(rest_utils.consts.err.invalid_args)
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
      if old_pool_name == pools.DROP_HOST_POOL_NAME and ntop.isPro() then
	 package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
	 local policy_utils = require "policy_utils"

	 policy_utils.broadcast_ips_rules()
      end
   else
      -- Bind the member only if it is not already in another pool
      res, err = s:bind_member_if_not_already_bound(member, pool_id)
   end

   if not res then
      if err == pools.ERRORS.ALREADY_BOUND then
	 -- Member already existing, return current pool information in the response
	 local cur_pool = s:get_pool_by_member(member)
	 rest_utils.answer(rest_utils.consts.err.bind_pool_member_already_bound, cur_pool)
      else
	 -- Generic
	 rest_utils.answer(rest_utils.consts.err.bind_pool_member_failed)
      end

      return
   end

   local rc = rest_utils.consts.success.pool_member_bound
   rest_utils.answer(rc)

   local dst_pool = s:get_pool(pool_id)

   -- TRACKER HOOK
   tracker.log('bind_pool_member', { pool_id = pool_id, pool_name = dst_pool["name"], member = member, pool_key = s.key })
end

-- ##############################################

-- @brief Get one or all pools
function pools_rest_utils.get_pools(pools)
   local pool_id = _GET["pool"]

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
	 rest_utils.answer(rest_utils.consts.err.pool_not_found)
	 return
      end
   else
      -- Return all pool ids
      res = s:get_all_pools()
   end

   local rc = rest_utils.consts.success.ok
   rest_utils.answer(rc, res)
end

-- ##############################################

-- @brief Get all pools of all the available (currently implemented) pool instances matching a given `recipient_id`
function pools_rest_utils.get_all_instances_pools_by_recipient(recipient_id)
   local res = {}
   local all_instances = pools_lua_utils.all_pool_instances_factory()

   for _, instance in pairs(all_instances) do
      local instance_pools = instance:get_all_pools()

      for _, instance_pool in pairs(instance_pools) do
	 instance_pool["key"] = instance.key -- e.g., 'interface', 'host', etc.
	 for _, recipient in pairs(instance_pool["recipients"]) do
	    if tonumber(recipient.recipient_id) == (recipient_id) then
	       -- Match, return the recipient
	       instance_pool["key"] = instance.key -- e.g., 'interface', 'host', etc.
	       res[#res + 1] = instance_pool
	       break
	    end
	 end
      end
   end

   local rc = rest_utils.consts.success.ok
   rest_utils.answer(rc, res)
end

-- ##############################################

-- @brief Get all pools of all the available (currently implemented) pool instances
function pools_rest_utils.get_all_instances_pools()
   local res = {}
   local all_instances = pools_lua_utils.all_pool_instances_factory()

   for _, instance in pairs(all_instances) do
      local instance_pools = instance:get_all_pools()

      for _, instance_pool in pairs(instance_pools) do
	 instance_pool["key"] = instance.key -- e.g., 'interface', 'host', etc.
	 res[#res + 1] = instance_pool
      end
   end

   local rc = rest_utils.consts.success.ok
   rest_utils.answer(rc, res)
end

-- ##############################################

-- @brief Get all pools of all the available (currently implemented) pool instances
function pools_rest_utils.delete_all_instances_pools()
   local all_instances = pools_lua_utils.all_pool_instances_factory()

   for _, instance in pairs(all_instances) do
      instance:cleanup()
   end

   local rc = rest_utils.consts.success.ok
   rest_utils.answer(rc)
end

-- ##############################################

-- @brief Get one or all pools
function pools_rest_utils.get_pool_members(pools)
   local pool_id = _GET["pool"]

   -- pool_id as number
   pool_id = tonumber(pool_id)

   local res = {}

   -- Create the instance
   local s = pools:create()

   local cur_pool = s:get_pool(pool_id)

   if not cur_pool then
      rest_utils.answer(rest_utils.consts.err.pool_not_found)
      return
   end

   for member, details in pairs(cur_pool["member_details"]) do
      details["member"] = member
      res[#res + 1] = details
   end

   local rc = rest_utils.consts.success.ok
   rest_utils.answer(rc, res)
end

-- ##############################################

-- @brief Get one or all pools
function pools_rest_utils.get_pool_by_member(pools)
   local member = _POST["member"]

   if not member then
      rest_utils.answer(rest_utils.consts.err.invalid_args)
      return
   end

   local res = {}

   -- Create the instance
   local s = pools:create()
   local cur_pool = s:get_pool_by_member(member)
   if cur_pool then
      res = cur_pool
   end

   local rc = rest_utils.consts.success.ok
   rest_utils.answer(rc, res)
end

-- ##############################################

return pools_rest_utils
