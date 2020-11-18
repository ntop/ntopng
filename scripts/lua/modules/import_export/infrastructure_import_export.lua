--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils" 
local import_export = require "import_export"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local pools = require("pools")
local infrastructure_utils = require("infrastructure_utils")
local plugins_utils = require("plugins_utils")
local am_utils = plugins_utils.loadModule("active_monitoring", "am_utils")

-- ##############################################

local infrastructure_import_export = {}

-- ##############################################

function infrastructure_import_export:create(args)
    -- Instance of the base class
    local _infrastructure_import_export = import_export:create()

    -- Subclass using the base class instance
    self.key = "infrastructure"
    -- self is passed as argument so it will be set as base class metatable
    -- and this will actually make it possible to override functions
    local _infrastructure_import_export_instance = _infrastructure_import_export:create(self)

    -- Return the instance
    return _infrastructure_import_export_instance
end

-- ##############################################

-- @brief Import configuration
-- @param conf The configuration to be imported
-- @return A table with a key "success" set to true is returned on success. A key "err" is set in case of failure, with one of the errors defined in rest_utils.consts.err.
function infrastructure_import_export:import(conf)
   local res = {}

   local success, restored = infrastructure_utils.restore(conf)

   if not success then
      res.err = rest_utils.consts.err.internal_error
   else

      -- set success to true
      res.success = true
      -- restore active monitoring hosts
      for _, instance in ipairs(restored) do
         -- add the instance to the active monitoring
         infrastructure_utils.add_instance_to_active_monitoring(instance)
      end
   end

   return res
end

-- ##############################################

-- @brief Export configuration
-- @return The current configuration
function infrastructure_import_export:export()
   local conf = infrastructure_utils.get_all_instances()
   return conf
end

-- ##############################################

-- @brief Reset configuration
function infrastructure_import_export:reset()

   local removed_instances = infrastructure_utils.remove_all_instances()

   for _, instance in ipairs(removed_instances) do
      -- get the measurement from the url
      infrastructure_utils.delete_from_active_monitoring(instance)
   end

end

-- ##############################################

return infrastructure_import_export