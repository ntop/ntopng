--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path
require "lua_utils" 
local import_export = require "import_export"
local json = require "dkjson"
local user_scripts = require "user_scripts"
local rest_utils = require "rest_utils"

-- ##############################################

local scripts_import_export = {}

-- ##############################################

function scripts_import_export:create(args)
    -- Instance of the base class
    local _scripts_import_export = import_export:create()

    -- Subclass using the base class instance
    self.key = "scripts"
    -- self is passed as argument so it will be set as base class metatable
    -- and this will actually make it possible to override functions
    local _scripts_import_export_instance = _scripts_import_export:create(self)

    -- Compute

    -- Return the instance
    return _scripts_import_export_instance
end

-- ##############################################

-- @brief Import configuration
-- @param conf The configuration to be imported
-- @return A table with a key "success" set to true is returned on success. A key "err" is set in case of failure, with one of the errors defined in rest_utils.consts.err.
function scripts_import_export:import(conf)
   local res = {}

   if table.empty(conf) then
      res.err = rest_utils.consts.err.bad_format
      return res
   end

   if conf["0"] == nil then
      res.err = rest_utils.consts.err.bad_content
      return res
   end

   for config_id, config_set in pairs(conf) do
      if config_set.name ~= nil then
         local success, err = user_scripts.createOrReplaceConfigset(config_set)
         if not success then
            res.err = rest_utils.consts.err.internal_error
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
function scripts_import_export:export()
   local conf = user_scripts.getConfigsets()
   return conf
end

-- ##############################################

-- @brief Reset configuration
function scripts_import_export:reset()
   user_scripts.resetConfigsets()
end

-- ##############################################

return scripts_import_export
