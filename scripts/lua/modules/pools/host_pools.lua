--
-- (C) 2017-20 - ntop.org
--

-- Module to keep things in common across pools of various type

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
require "lua_utils"
local base_pools = require "base_pools"
local user_scripts = require "user_scripts"
local json = require "dkjson"

-- ##############################################

local host_pools = {}

-- ##############################################

function host_pools:create(args)
   -- Instance of the base class
   local _host_pools = base_pools:create()

   -- Subclass using the base class instance
   self.key = "host"
   -- self is passed as argument so it will be set as base class metatable
   -- and this will actually make it possible to override functions
   local _host_pools_instance = _host_pools:create(self)

   -- Compute

   -- Return the instance
   return _host_pools_instance
end

-- ##############################################

-- @brief Given a member key, returns a table of member details such as member name.
function host_pools:get_member_details(member)
   -- Only the name is relevant for hosts
   return {name = member}
end

-- ##############################################

-- @brief Returns a table of all possible host ids, both assigned and unassigned to pool members
function host_pools:get_all_members()
   -- There is not a fixed set of host members for host pools
   return
end

-- ##############################################

function host_pools:_get_pools_prefix_key()
   -- OVERRIDE
   -- Key name is in sync with include/ntop_defines.h
   -- and with former host_pools_utils.lua
   local key = string.format("ntopng.prefs.host_pools")

   return key
end

-- ##############################################

function host_pools:_get_pool_ids_key()
   -- OVERRIDE
   -- Key name is in sync with include/ntop_defines.h
   -- and with former host_pools_utils.lua method get_pool_ids_key()
   local key = string.format("%s.pool_ids", self:_get_pools_prefix_key())

   return key
end

-- ##############################################

function host_pools:_get_pool_details_key(pool_id)
   -- OVERRIDE
   -- Key name is in sync with include/ntop_defines.h
   -- and with former host_pools_utils.lua method get_pool_details_key(pool_id)

   if not pool_id then
      -- A pool id is always needed
      return nil
   end

   local key = string.format("%s.details.%d", self:_get_pools_prefix_key(), pool_id)

   return key
end

-- ##############################################

function host_pools:_get_pool_members_key(pool_id)
   -- Key name is in sync with include/ntop_defines.h
   -- and with former host_pools_utils.lua method get_pool_members_key(pool_id)

   if not pool_id then
      -- A pool id is always needed
      return nil
   end

   local key = string.format("%s.members.%d", self:_get_pools_prefix_key(), pool_id)

   return key
end

-- ##############################################

function host_pools:_assign_pool_id()
   -- OVERRIDE
   -- To stay consistent with the old implementation host_pools_utils.lua
   -- pool_ids are re-used. This means reading the set  of currently used pool
   -- ids, and chosing the minimum not available pool id
   -- This method is called from functions which perform locks so
   -- there's no risk to assign the same id multiple times
   local cur_pool_ids = self:_get_assigned_pool_ids()

   local next_pool_id = base_pools.MIN_ASSIGNED_POOL_ID

   -- Find the first available pool id which is not in the set
   for _, pool_id in pairsByValues(cur_pool_ids, asc) do
      if pool_id > next_pool_id then
	 break
      end

      next_pool_id = math.max(pool_id + 1, next_pool_id)
   end

   ntop.setMembersCache(self:_get_pool_ids_key(), string.format("%d", next_pool_id))

   return next_pool_id
end

-- ##############################################

-- @brief Persist pool details to disk. Possibly assign a pool id
-- @param pool_id The pool_id of the pool which needs to be persisted. If nil, a new pool id is assigned
function host_pools:_persist(pool_id, name, members, configset_id)
   -- OVERRIDE
   -- Method must be overridden as host pool details and members are kept as hash caches, which are also used by the C++

   -- The cache for the pool
   local pool_details_key = self:_get_pool_details_key(pool_id)
   ntop.setHashCache(pool_details_key, "name", name)
   ntop.setHashCache(pool_details_key, "configset_id", tostring(configset_id))

   -- The cache for pool members
   local pool_members_key = self:_get_pool_members_key(pool_id)
   ntop.delCache(pool_members_key)
   for _, member in pairs(members) do
      ntop.setMembersCache(pool_members_key, member)
   end

   -- Reload pools
   ntop.reloadHostPools()

   -- Return the assigned pool_id
   return pool_id
end

-- ##############################################

function host_pools:delete_pool(pool_id)
   local ret = false

   local locked = self:_lock()

   if locked then
      -- Make sure the pool exists
      local cur_pool_details = self:get_pool(pool_id)

      if cur_pool_details then
	 -- Remove the key with all the pool details (e.g., with members, and configset_id)
	 ntop.delCache(self:_get_pool_details_key(pool_id))

	 -- Remove the key with all the pool member details
	 ntop.delCache(self:_get_pool_members_key(pool_id))

	 -- Remove the pool_id from the set of all currently existing pool ids
	 ntop.delMembersCache(self:_get_pool_ids_key(), string.format("%d", pool_id))

	 -- Reload pools
	 ntop.reloadHostPools()

	 ret = true
      end

      self:_unlock()
   end

   return ret
end

-- ##############################################

function host_pools:_get_pool_detail(pool_id, detail)
   local details_key = self:_get_pool_details_key(pool_id)

   return ntop.getHashCache(details_key, detail)
end

-- ##############################################

function host_pools:get_pool(pool_id)
   local pool_details
   local cur_pool_ids = ntop.getMembersCache(self:_get_pool_ids_key())

   -- Attempt at retrieving the pool details key and at decoding it from JSON
   local pool_name = self:_get_pool_detail(pool_id, "name")

   if pool_name and pool_name ~= "" then
      -- If the requested pool exists...
      pool_details = {pool_id = tonumber(pool_id), name = pool_name}

      -- Add configset and configset details
      local configset_id = self:_get_pool_detail(pool_id, "configset_id")
      pool_details["configset_id"] = tonumber(configset_id) or user_scripts.DEFAULT_CONFIGSET_ID
      local config_sets = user_scripts.getConfigsets()

      -- Add a new (small) table with configset details, including the name
      if config_sets[configset_id] and config_sets[configset_id]["name"] then
	 pool_details["configset_details"] = {name = config_sets[configset_id]["name"]}
      end

      -- Add pool members
      pool_details["members"] = ntop.getMembersCache(self:_get_pool_members_key(pool_id))

      if pool_details["members"] then
	 pool_details["member_details"] = {}
	 for _, member in pairs(pool_details["members"]) do
	    pool_details["member_details"][member] = self:get_member_details(member)
	 end
      end
   end

   -- Upon success, pool details are returned, otherwise nil
   return pool_details
end

-- ##############################################

-- @brief Returns a boolean indicating whether the member is a valid pool member
function host_pools:is_valid_member(member)
   local res = isValidPoolMember(member)

   return res
end

-- ##############################################

-- @brief Returns available members which don't already belong to any defined pool
function host_pools:get_available_members()
   -- Available host pool memebers is not a finite set
   return nil
end

-- ##############################################

return host_pools
