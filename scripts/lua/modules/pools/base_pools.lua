--
-- (C) 2017-20 - ntop.org
--

-- Module to keep things in common across pools of various type

require "lua_utils"
local user_scripts = require "user_scripts"
local base_pools = {}

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
