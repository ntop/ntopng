--
-- (C) 2020 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path

local prefs_dump_utils = require "prefs_dump_utils"

-- ##############################################

local all_import_export = {}

-- ##############################################

function all_import_export:create(args)
    local import_export = require "import_export"
    -- Instance of the base class
    local _all_import_export = import_export:create()

    -- Subclass using the base class instance
    self.key = "all"
    -- self is passed as argument so it will be set as base class metatable
    -- and this will actually make it possible to override functions
    local _all_import_export_instance = _all_import_export:create(self)

    -- Compute

    -- Return the instance
    return _all_import_export_instance
end

-- ##############################################

-- @brief Import configuration
-- @param conf The configuration to be imported
-- @return A table with a key "success" set to true is returned on success. A key "err" is set in case of failure, with one of the errors defined in rest_utils.consts.err.
function all_import_export:import(conf)
    local rest_utils = require "rest_utils"
    local res = {}

    -- local success = all_config.restore(conf)
    local success = prefs_dump_utils.import_prefs_to_disk(conf)
    tprint(success)

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
function all_import_export:export()
    local prefs_dump = prefs_dump_utils.build_prefs_dump_table()

    -- Remove the config_save_backup key, if any,
    -- as it produces a huge json and it is not really required
    prefs_dump['ntopng.prefs.config_save_backup'] = nil

    return prefs_dump
end

-- ##############################################

-- @brief Reset configuration
function all_import_export:reset()
    local prefs_factory_reset_utils = require "prefs_factory_reset_utils"
    prefs_factory_reset_utils.request_prefs_factory_reset()
end

-- ##############################################

return all_import_export
