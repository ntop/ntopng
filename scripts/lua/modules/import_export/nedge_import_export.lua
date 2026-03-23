--
-- (C) 2020-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path

local json = require "dkjson"

-- ##############################################

local nedge_import_export = {}

-- ##############################################

function nedge_import_export:create(args)
    local import_export = require "import_export"
    -- Instance of the base class
    local _nedge_import_export = import_export:create()

    -- Subclass using the base class instance
    self.key = "system_config"
    -- self is passed as argument so it will be set as base class metatable
    -- and this will actually make it possible to override functions
    local _nedge_import_export_instance = _nedge_import_export:create(self)

    -- Return the instance
    return _nedge_import_export_instance
end

-- ##############################################

-- @brief Import configuration
-- @param conf The configuration to be imported
-- @return A table with a key "success" set to true is returned on success. A key "err" is set in case of failure, with one of the errors defined in rest_utils.consts.err.
function nedge_import_export:import(conf)
    local rest_utils = require "rest_utils"
    local res = {}

    local system_config_path = dirs.workingdir .. "/system.config"
    local f = io.open(system_config_path, "w")
    if not f then
        res.err = rest_utils.consts.err.internal_error
        return res
    end

    f:write(json.encode(conf))
    f:close()
    res.success = true

    return res
end

-- ##############################################

-- @brief Export configuration
-- @return The current configuration
function nedge_import_export:export()
    local system_config_path = dirs.workingdir .. "/system.config"
    local f = io.open(system_config_path, "r")
    if not f then
        return {}
    end

    local content = f:read("*a")
    f:close()

    return json.decode(content) or {}
end

-- ##############################################

return nedge_import_export
