--
-- (C) 2013-23 - ntop.org
--
--
-- This script implements the backup of ntopng configurations
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path

-- ##############################################

require "lua_utils"
local all_import_export = require "all_import_export"
local import_export_rest_utils = require "import_export_rest_utils"
local rest_utils = require("rest_utils")
local json = require("dkjson")

-- ##############################################

local action = nil -- _GET["action"]
local backup_hash_key = "ntopng.cache.config_save_backup"
local backup_config = {}

local debugger = false

-- ##############################################

local function remove_last(epoch_keys)
    for key, _ in pairsByKeys(epoch_keys or {}, asc) do
        if debugger then
            traceError(TRACE_DEBUG, TRACE_CONSOLE, "Removing the key: " .. key)
        end

        ntop.delHashCache(backup_hash_key, key)
        break
    end
end

-- ##############################################

-- @brief Save configurations backup.
function backup_config.save_backup()
    local instances = {}
    -- Retrieve the configuration
    instances["all"] = all_import_export:create()
    local backup = import_export_rest_utils.export(instances, false, true)
    if debugger then
        traceError(TRACE_DEBUG, TRACE_CONSOLE, "START BACKUP SAVING")
    end

    -- Get all the keys
    local key = tostring(os.time())
    local saved_backups_keys = ntop.getHashKeysCache(backup_hash_key) or {}
    local num_saved_backups = table.len(saved_backups_keys) or 0

    -- Check the currently saved backups
    if (num_saved_backups >= 7) then
        remove_last(saved_backups_keys)
    end

    if (saved_backups_keys and num_saved_backups >= 1) then
        -- Save the configuration on redis only if the configuration has some changes
        -- between the last saved configuration, using the pairsByKeys just to order the
        -- keys from the last added to the first one.
        for item, _ in pairsByKeys(saved_backups_keys, rev) do
            local last_config = json.decode(ntop.getHashCache(backup_hash_key, item)) or {}
            -- Check if the last configuration is equal to the current one
            if not (last_config == backup) then
                if debugger then
                    traceError(TRACE_DEBUG, TRACE_CONSOLE, "Saving Backup: " .. backup .. "\nUsing Redis key: " .. key)
                end

                ntop.setHashCache(backup_hash_key, key, json.encode(backup))
                break
            end
        end
    else
        -- Save the backup
        if debugger then
            traceError(TRACE_DEBUG, TRACE_CONSOLE, "Saving Backup: " .. backup .. "\nUsing Redis key: " .. key)
        end

        ntop.setHashCache(backup_hash_key, key, json.encode(backup))
    end
end

-- ##############################################

-- @brief List all configurations backup.
function backup_config.list_backup(user)
    local saved_backups_keys = ntop.getHashKeysCache(backup_hash_key) or {}
    local epoch_list = {}
    local date_format = ntop.getPref("ntopng.user."..user..".date_format")

    local format = ""
    if(date_format == "little_endian") then
        format = "DD/MMM/YYYY"
    elseif(date_format == "middle_endian") then
        format = "MMM/DD/YYYY"
    else
        format = "YYYY/MMM/DD"
    end

    for epoch, _ in pairs(saved_backups_keys) do
        epoch_list[#epoch_list + 1] = {
            epoch = epoch,
            format = format
        }
    end

    return epoch_list
end

-- ##############################################

-- @brief Export configuration backup.
function backup_config.export_backup(epoch)
    if (epoch == nil or isEmptyString(epoch)) then
        return false, {}
    end

    local backup_to_restore = json.decode(ntop.getHashCache(backup_hash_key, epoch)) or {}
    return true, json.encode(backup_to_restore)
end

-- ##############################################

return backup_config
