--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path
require "lua_utils" 
local import_export = require "import_export"
local json = require "dkjson"
local checks = require "checks"
local alert_exclusions = require "alert_exclusions"
local rest_utils = require "rest_utils"

-- ##############################################

local checks_import_export = {}

-- ##############################################

function checks_import_export:create(args)
    -- Instance of the base class
    local _checks_import_export = import_export:create()

    -- Subclass using the base class instance
    self.key = "scripts"
    -- self is passed as argument so it will be set as base class metatable
    -- and this will actually make it possible to override functions
    local _checks_import_export_instance = _checks_import_export:create(self)

    -- Compute

    -- Return the instance
    return _checks_import_export_instance
end

-- ##############################################

-- @brief Import configuration
-- @param conf The configuration to be imported
-- @return A table with a key "success" set to true is returned on success. A key "err" is set in case of failure, with one of the errors defined in rest_utils.consts.err.
function checks_import_export:import(conf)
   local res = {}

   if table.empty(conf) then
      res.err = rest_utils.consts.err.bad_format
      return res
   end

   local config_set = conf[tostring(checks.DEFAULT_CONFIGSET_ID)]

   if config_set == nil then
      res.err = rest_utils.consts.err.bad_content
      return res
   end

   -- Import the default config_set only (others are deprecated)
   -- This used to be: for config_id, config_set in pairs(conf) do

   local success = checks.createOrReplaceConfigset(config_set)

   if not success then
      res.err = rest_utils.consts.err.internal_error
   end

   if not res.err then

      -- Import exclusions (if present)
      if conf["alert_exclusions"] then
	 alert_exclusions.import(conf["alert_exclusions"])
      end

      res.success = true
   end

   return res
end

-- ##############################################

-- @brief Export configuration
-- @return The current configuration
function checks_import_export:export()
   local conf = {}

   conf[checks.DEFAULT_CONFIGSET_ID] = checks.getConfigset()
   conf["alert_exclusions"] = alert_exclusions.export()

   return conf
end

-- ##############################################

-- @brief Reset configuration
function checks_import_export:reset()
   checks.resetConfigset()
end

-- ##############################################

return checks_import_export
