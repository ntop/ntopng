--
-- (C) 2017-20 - ntop.org
--

-- Module to keep things in common across pools of various type

require "lua_utils"
local user_scripts = require "user_scripts"
local json = require "dkjson"

-- ##############################################

local base_pools = {}

-- ##############################################

function base_pools:create(args)
   if args then
      -- We're being sub-classed
      if not args.key then
	 return nil
      end
   end

   local this = args or {key = "base"}

   setmetatable(this, self)
   self.__index = self

   return this
end

-- ##############################################

function base_pools:_get_pools_prefix_key()
   local key = string.format("ntopng.pools.%s_pools", self.key)
   -- e.g.:
   --  ntopng.pools.interface_pools
   --  ntopng.pools.snmp_device_pools
   --  ntopng.pools.network_pools

   return key
end

-- ##############################################

function base_pools:_get_pool_ids_key()
   local key = string.format("%s.pool_ids", self:_get_pools_prefix_key())
   -- e.g.:
   --  ntopng.pools.interface_pools.pool_ids

   return key
end

-- ##############################################

function base_pools:_get_next_pool_id_key()
   local key = string.format("%s.next_pool_id", self:_get_pools_prefix_key())
   -- e.g.:
   --  ntopng.pools.interface_pools.next_pool_id

   return key
end

-- ##############################################

function base_pools:_get_pool_details_key(pool_id)
   if not pool_id then
      -- A pool id is always needed
      return nil
   end

   local key = string.format("%s.pool_id_%d.next_pool_id", self:_get_pools_prefix_key(), pool_id)
   tprint(key)
   return key
end

-- ##############################################

function base_pools:_assign_pool_id()
   local next_pool_id_key = self:_get_next_pool_id_key()
   -- Atomically assign a new pool id
   local next_pool_id = ntop.incrCache(next_pool_id_key)

   -- Add the atomically assigned pool id to the set of current pool ids (set wants a string)
   ntop.setMembersCache(self:_get_pool_ids_key(), string.format("%d", next_pool_id))

   -- tprint({next_pool_id = next_pool_id, pool_ids = ntop.getMembersCache(self:_get_pool_ids_key())})
   return next_pool_id
end

-- ##############################################

-- @brief Persist pool details to disk. Possibly assign a pool id
-- @param pool_id The pool_id of the pool which needs to be persisted. If nil, a new pool id is assigned
function base_pools:_persist(pool_id, name, members, configset_id)
   -- self:cleanup()

   local pool_details_key = self:_get_pool_details_key(pool_id)
   local pool_details = {
      name = name,
      members = members,
      configset_id = configset_id
   }
   ntop.setCache(pool_details_key, json.encode(pool_details))

   -- Return the assigned pool_id
   return pool_id
end

-- ##############################################

function base_pools:add_pool(name, members, configset_id)
   local pool_id

   -- TODO: LOCK

   if name and members and configset_id then
      -- Check if duplicate names exist
      -- Check if members are valid and do not belong to any other pool
      -- Check if the configset_id is valid

      if true then -- TODO: implement checks
	 -- All the checks have succeeded
	 -- Now that everything is ok, the id can be assigned
	 pool_id = self:_assign_pool_id()

	 -- Data can now be persisted with the new pool_id
	 self:_persist(pool_id, name, members, configset_id)
      end
   end

   -- TODO: UNLOCK

   return pool_id
end

-- ##############################################

function base_pools:edit_pool(pool_id, new_name, new_members, new_configset_id)
   local ret = false

   -- TODO: LOCK

   -- Make sure the pool exists
   local cur_pool_details = self:get_pool(pool_id)

   -- If here, pool_id has been found
   if cur_pool_details and new_name and new_members and new_configset_id then
      -- Check if new_name is not the name of any other existing pool
      -- Check if none of new_members belongs to any other exsiting pool
      -- Check if the configset_id is valid

      if true then -- TODO: implement checks
	 -- If here, all checks are valid and the pool can be edited
	 self:_persist(pool_id, new_name, new_members, new_configset_id)

	 -- Pool edited successfully
	 ret = true
      end
   end

   -- TODO: UNLOCK

   return ret
end

-- ##############################################

function base_pools:delete_pool(pool_id)
   local ret = false

   -- TODO: LOCK

   -- Make sure the pool exists
   local cur_pool_details = self:get_pool(pool_id)

   if cur_pool_details then
      -- Remove the key with all the pool details (e.g., with members, and configset_id)
      ntop.delCache(self:_get_pool_details_key(pool_id))

      -- Remove the pool_id from the set of all currently existing pool ids
      ntop.delMembersCache(self:_get_pool_ids_key(), string.format("%d", pool_id))
   end

   -- TODO: UNLOCK

   return ret
end

-- ##############################################

function base_pools:get_pool(pool_id)
   local pool_details
   local pool_details_key = self:_get_pool_details_key(pool_id)

   -- Attempt at retrieving the pool details key and at decoding it from JSON
   if pool_details_key then
      local pool_details_str = ntop.getCache(pool_details_key)
      pool_details = json.decode(pool_details_str)
   end

   -- Upon success, pool details are returned, otherwise nil
   return pool_details
end

-- ##############################################

function base_pools:cleanup()
   -- TODO: LOCK

   -- Delete pool details
   local cur_pool_ids = ntop.getMembersCache(self:_get_pool_ids_key())
   for _, pool_id in pairs(cur_pool_ids) do
      ntop.delCache(self:_get_pool_details_key(pool_id))
   end

   -- Delete pool ids
   ntop.delCache(self:_get_pool_ids_key())
   ntop.delCache(self:_get_next_pool_id_key())

   -- TODO: UNLOCK
end

-- ##############################################

-- @brief Returns available confset ids which can be added to a pool
function base_pools:list_available_configset_ids()
   -- Currently, confset_ids are shared across pools of all types
   -- so all the confset_ids can be returned here without distinction
   local config_sets = user_scripts.getConfigsets()
   local res = {}

   for _, configset in pairs(config_sets) do
      res[#res + 1] = {configset_id = configset.id, configset_name = configset.name}
   end

   return res
end

return base_pools
