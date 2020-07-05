--
-- (C) 2017-20 - ntop.org
--

-- Module to keep things in common across pools of various type

require "lua_utils"
local user_scripts = require "user_scripts"

-- ##############################################

local base_pools = {}

-- ##############################################

local base_pools_prefix = "ntopng.pools"

-- ##############################################

function base_pools:create(args)
   if args then
      -- We're being sub-classed
      if not args.key or not args.name or not args.members or not args.configset_id then
	 return nil
      end
   end

   local this = args or {key = "base", members = {}, configset_id = 0}

   setmetatable(this, self)
   self.__index = self

   return this
end

-- ##############################################

function base_pools:_get_pool_ids_key()
   return string.format("%s.%s_pools.pool_ids", base_pools_prefix, self.key)
end

-- ##############################################

function base_pools:_get_next_pool_id_key()
   return string.format("%s.%s_pools.next_pool_id", base_pools_prefix, self.key)
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

function base_pools:_persist()
   io.write("persist")
   -- self:cleanup()

   -- LOCK

   -- Check if duplicate names exist
   -- Check is members are valid and do not belong to any other pool
   -- Check if the configset_id is valid

   -- Now that everything is ok, the id can be assigned
   local pool_id = self:_assign_pool_id()

   -- UNLOCK

   -- Set the pool id to the current instance
   self.pool_id = pool_id
   return true
end

-- ##############################################

function base_pools:cleanup()
   ntop.delCache(self:_get_pool_ids_key())
   ntop.delCache(self:_get_next_pool_id_key())
end

-- ##############################################

function base_pools.list_available_configset_ids()
   -- Currently, confset_ids are shared across pools of all types
   -- so all the confset_ids can be returned here without distinction
   local config_sets = user_scripts.getConfigsets()
   local res = {}

   for _, configset in pairs(config_sets) do
      res[#res + 1] = {configset_id = configset.id, configset_name = configset.name}
   end

   return res
end

-- ##############################################

return base_pools
