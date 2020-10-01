--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/notifications/lua/modules/import_export/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils" 
local import_export = require "import_export"
local json = require "dkjson"
local notification_configs = require "notification_configs"
local rest_utils = require "rest_utils"

-- ##############################################

local notifications_import_export = {}

-- ##############################################

function notifications_import_export:create(args)
    -- Instance of the base class
    local _notifications_import_export = import_export:create()

    -- Subclass using the base class instance
    self.key = "notifications"
    -- self is passed as argument so it will be set as base class metatable
    -- and this will actually make it possible to override functions
    local _notifications_import_export_instance = _notifications_import_export:create(self)

    -- Compute

    -- Return the instance
    return _notifications_import_export_instance
end

-- ##############################################

-- @brief Import configuration
-- @param conf The configuration to be imported
-- @return A table with a key "success" set to true is returned on success. A key "err" is set in case of failure, with one of the errors defined in rest_utils.consts.err.
function notifications_import_export:import(conf)
   local res = {}

   local success = notification_configs.add_configs_with_recipients(conf)

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
function notifications_import_export:export()
   local conf = notification_configs.get_configs_with_recipients()
   return conf
end

-- ##############################################

-- @brief Reset configuration
function notifications_import_export:reset()
   notification_configs.reset_configs()
end

-- ##############################################

return notifications_import_export
