--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/snmp/lua/modules/import_export/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils" 
local import_export = require "import_export"
local json = require "dkjson"
local snmp_config = require "snmp_config"
local rest_utils = require "rest_utils"

-- ##############################################

local snmp_import_export = {}

-- ##############################################

function snmp_import_export:create(args)
    -- Instance of the base class
    local _snmp_import_export = import_export:create()

    -- Subclass using the base class instance
    self.key = "snmp"
    -- self is passed as argument so it will be set as base class metatable
    -- and this will actually make it possible to override functions
    local _snmp_import_export_instance = _snmp_import_export:create(self)

    -- Compute

    -- Return the instance
    return _snmp_import_export_instance
end

-- ##############################################

-- @brief Import configuration
-- @param conf The configuration to be imported
-- @return A table with a key "success" set to true is returned on success. A key "err" is set in case of failure, with one of the errors defined in rest_utils.consts.err.
function snmp_import_export:import(conf)
   local res = {}

   local success = snmp_config.restore(conf)

   if not success then
      res.err = rest_utils.consts.err.internal_error
   else
      res.success = true
   end

   return res
end

-- ##############################################

-- @brief Export configuration
-- @return The current configuration
function snmp_import_export:export()
   local conf = snmp_config.export()
   return conf
end

-- ##############################################

return snmp_import_export
