--
-- (C) 2013-24 - ntop.org
--
--
-- This script implements the backup of ntopng configurations
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path

-- ##############################################

require "ntop_utils"
local json = require("dkjson")

-- ##############################################

local action = nil -- _GET["action"]
local backup_hash_key            = "ntopng.cache.config_save_backup"
local backup_fs_path             = '/configurations'
local windows_baackup_fs_path    = '\\configurations'
local dir_path_separator         = '/'
local windows_dir_path_separator = '\\'

local backup_config = {}

local debugger = false

-- ##############################################

local function remove_last(epoch_keys)
    for key, _ in pairsByKeys(epoch_keys or {}, asc) do
        if debugger then
            traceError(TRACE_DEBUG, TRACE_CONSOLE, "Removing the key: " .. key)
        end

        ntop.delHashCache(backup_hash_key, key)
        break -- take the first one
    end
end

-- ##############################################

-- @brief Retrieve configurations backup.
function backup_config.exec_backup()
    local all_import_export = require "all_import_export"
    local import_export_rest_utils = require "import_export_rest_utils"
    local instances = {}
    local to_ignore = {
        last_poll_time = true,
        last_poll_duration = true,
        num_interfaces_with_errors = true,
        delta_interfaces_with_errors = true
    }

    -- Retrieve the configuration
    instances["all"] = all_import_export:create()
    local backup = import_export_rest_utils.export(instances, false, true)
    
    local new_backup_key = tostring(os.time())

    backup_config.fs_save_backup(new_backup_key, backup, to_ignore)
    backup_config.save_backup(new_backup_key, backup, to_ignore)
end

-- #################################################

-- @brief Save configurations backup on File System.
function backup_config.fs_save_backup(backup_time_key, backup, to_ignore)
    
    if debugger then
        traceError(TRACE_DEBUG, TRACE_CONSOLE, "START BACKUP SAVING ON FS")
    end

    local key = backup_time_key

    local backup_config_dir     = backup_fs_path
    local path_separator        = dir_path_separator
    
    if ntop.isWindows() then
        backup_config_dir       = windows_baackup_fs_path
        path_separator          = windows_dir_path_separator
    end

    local base_dir              = dirs.workingdir..backup_config_dir

    ntop.mkdir(base_dir)
    local backup_files = {}

    local last_b_name = "" -- backup more recent
    local first_b_name = "" -- backup older

    local num_backups = 0

    for dir,_ in pairs(ntop.readdir(base_dir)) do
        if (not isEmptyString(dir)) then
            num_backups = num_backups + 1
            backup_files[dir] = dir
            if (isEmptyString(last_b_name)) then 
                last_b_name = dir 
            elseif (dir > last_b_name) then
                last_b_name = dir
            end
            if (isEmptyString(first_b_name)) then 
                first_b_name = dir 
            elseif (dir < first_b_name) then
                first_b_name = dir
            end
        end
    end

    -- get last backup
    local handle = io.open(base_dir..path_separator..last_b_name, "r")
    local backup_string
    if handle then
        backup_string = handle:read("*a")
        handle:close()
    end

    if (num_backups >= 7) then
        -- remove here the first_b_name
        os.remove(base_dir..path_separator..first_b_name)
    end

    local last_config = {}
    if (backup_string) then
        last_config = json.decode(backup_string) or {}
    end

    local save_backup = false
    if (num_backups >= 1) then
        if (not table.is_equal(last_config, backup, to_ignore)) then
            -- New backup is different from the last one case
            save_backup = true
        else
            -- do nothing
        end
    else 
        -- First Backup case
        save_backup = true
    end

    if (save_backup) then
        local backup_j_string = json.encode(backup)
        local writer = io.open(base_dir..path_separator..key.."_config.json","w")

        -- In case there is some error with permissions
        if writer then
            writer:write(backup_j_string)
            writer:close()
        else
            traceError(TRACE_WARNING, TRACE_CONSOLE, "Unable to save configuration backup: "..base_dir..path_separator..key.."_config.json")
        end
    end
    
end

-- ##############################################

-- @brief Save configurations backup on Redis.
function backup_config.save_backup(backup_time_key, backup, to_ignore)
    
    if debugger then
        traceError(TRACE_DEBUG, TRACE_CONSOLE, "START BACKUP SAVING ON REDIS")
    end

    -- Get all the keys
    local key = backup_time_key
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

            if (not table.is_equal(last_config, backup, to_ignore)) then
                -- tprint("CONFIGURATION CHANGED ****")
                if debugger then
                    traceError(TRACE_DEBUG, TRACE_CONSOLE, "Saving Backup: " .. backup .. "\nUsing Redis key: " .. key)
                end

                ntop.setHashCache(backup_hash_key, key, json.encode(backup))
            else
                -- tprint("CONFIGURATION [ " .. item .."]= ****")
            end

            break -- take the first one
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
function backup_config.list_backup(user, order)
    local saved_backups_keys = ntop.getHashKeysCache(backup_hash_key) or {}
    local epoch_list = {}

    local date_format = ntop.getPref("ntopng.user." .. user .. ".date_format")

    for epoch, _ in pairsByKeys(saved_backups_keys, rev) do
        epoch_list[#epoch_list + 1] = {
            epoch = epoch,
            date_format = date_format
        }
    end

    if order == "desc" then
        table.sort(epoch_list, function(x, y)
            return x.epoch > y.epoch
        end)
    else
        table.sort(epoch_list, function(x, y)
            return x.epoch < y.epoch
        end)

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
