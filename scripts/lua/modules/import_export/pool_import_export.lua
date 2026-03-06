--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils" 
local import_export = require "import_export"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local checks = require "checks"

local host_pools              = require "host_pools":create()

local pool_instances = {
  ["host"] = host_pools,
}

-- ##############################################

local pool_import_export = {}

-- ##############################################

function pool_import_export:create(args)
   -- Instance of the base class
   local _pool_import_export = import_export:create()

   -- Subclass using the base class instance
   self.key = "pool"
   -- self is passed as argument so it will be set as base class metatable
   -- and this will actually make it possible to override functions
   local _pool_import_export_instance = _pool_import_export:create(self)

   -- Compute

   -- Return the instance
   return _pool_import_export_instance
end

-- ##############################################

-- @brief Parse a CSV string and convert it into the pool conf format.
-- @param csv_data The raw CSV string
-- @return A table compatible with the pool conf format used by import()
function pool_import_export:parse_csv(csv_data)
   local conf = { host = {} }

   -- Map pool_name -> list of members
   local pools_map = {}

   for line in csv_data:gmatch("[^\r\n]+") do
      -- Skip empty lines and comment lines starting with #
      line = line:match("^%s*(.-)%s*$")
      if line ~= "" and not line:match("^#") then
         -- Split on whitespace, comma or semicolon: first token = address, second = pool name
         local member, pool_name = line:match("^(%S+)[%s,;]+(%S+)%s*$")

         if member and pool_name then
            -- Normalise IP: if @vlan is missing append @0 as default (vlan 0)
            if member:match("^%d+%.%d+%.%d+%.%d+/%d+$") then
               member = member .. "@0"
            end

            local is_ip   = member:match("^%d+%.%d+%.%d+%.%d+/%d+@%d+$")
            local is_mac  = member:match("^%x%x[:%-%.]%x%x[:%-%.]%x%x[:%-%.]%x%x[:%-%.]%x%x[:%-%.]%x%x$")

            if is_ip or is_mac then
               if not pools_map[pool_name] then
                  pools_map[pool_name] = {}
               end
               pools_map[pool_name][#pools_map[pool_name] + 1] = member
            else
               traceError(TRACE_WARNING, TRACE_CONSOLE,
                  "pool_import_export CSV: skipping invalid member format '" .. member .. "' on line: " .. line)
            end
         else
            traceError(TRACE_WARNING, TRACE_CONSOLE,
               "pool_import_export CSV: skipping malformed line: " .. line)
         end
      end
   end

   -- Convert map to the list format expected by import()
   for pool_name, members in pairs(pools_map) do
      conf.host[#conf.host + 1] = {
         name    = pool_name,
         members = members
      }
   end

   return conf
end

-- ##############################################

-- @brief Import configuration
-- @param conf The configuration to be imported
-- @return A table with a key "success" set to true is returned on success. A key "err" is set in case of failure, with one of the errors defined in rest_utils.consts.err.
function pool_import_export:import(conf)
   local res = {}
   local MAX_POOLS_NUMBER = host_pools:get_max_num_pools()
   for pool_name, pool_list in pairs(conf) do
      if pool_instances[pool_name] ~= nil then
         local pool_instance = pool_instances[pool_name]

         for i, pool_conf in ipairs(pool_list) do
            if i > MAX_POOLS_NUMBER then
               traceError(TRACE_ERROR, TRACE_CONSOLE, "Failure importing " .. #pool_list " pools (max supported is " .. MAX_POOLS_NUMBER .. ")")
               break
            end

            -- Add Pool
            local new_pool_id = pool_instance:add_pool(
               pool_conf.name,
               pool_conf.members
            )

	    if not new_pool_id then
	       -- Pool not created, it is likely it exists already,
	       -- trying importing/merging members
	       local ret, err = pool_instance:add_to_pool(
	          pool_conf.name,
		  pool_conf.members)
	    end
         end
      end
   end
   
   if not res.err then
      res.success = true
   end

   return res
end

-- ##############################################

-- @brief Export configuration
-- @return The current configuration
function pool_import_export:export()
   local conf = {}

   for pool_name, pool_instance in pairs(pool_instances) do
      local all_pools = pool_instance:get_all_pools() or {}
      local exported_pools = {}
      for i, pool_conf in ipairs(all_pools) do
         exported_pools[#exported_pools + 1] = {
            name = pool_conf.name,
            members = pool_conf.members
         }
      end
      conf[pool_name] = exported_pools
   end

   return conf
end

-- ##############################################

-- @brief Reset configuration
function pool_import_export:reset()
   for pool_name, pool_instance in pairs(pool_instances) do
      pool_instance:cleanup()
   end
end

-- ##############################################

return pool_import_export
