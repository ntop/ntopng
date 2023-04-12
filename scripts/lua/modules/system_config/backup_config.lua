--
-- (C) 2013-23 - ntop.org
--


local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path

-- ##############################################

require "lua_utils"
local all_import_export = require "all_import_export"
local import_export_rest_utils = require "import_export_rest_utils"
local rest_utils = require("rest_utils")
local json = require ("dkjson")

-- ##############################################

local action = _GET["action"]
local saved_backup_key = "ntopng.prefs.config_save_backup"
local backup_config = {}

local debugger = false

debugger = true

-- ##############################################

local function remove_last(epoch_keys) 

  table.sort(epoch_keys, function(a, b) return a[1].split('.')[4] < b[1].split('.')[4] end)
  if debugger then
    tprint(epoch_keys)
  end

  for item in pairs(epoch_keys) do 
    ntop.delCache(item)
    break
  end

end

-- ##############################################

local function count_entries(entries) 
  local count = 0
  for item in pairs(entries) do
    count = count + 1
  end
  return count

end

-- ##############################################

-- @brief Save configurations backup.
function backup_config.save_backup()

  local instances = {}
  instances["all"] = all_import_export:create()
  local backup = import_export_rest_utils.export(instances, false)

  if debugger then
    tprint("START BACKUP SAVING")
  end
  
  local now = os.time()
  local last_redis_key = saved_backup_key.."."..tostring(now)
  local actual_saved_backup = ntop.getKeysCache(saved_backup_key..".*") or {}
  local num_actual_saved_backup = count_entries(actual_saved_backup)

  -- check actual saved backups
  if (num_actual_saved_backup == 7) then
    remove_last(actual_saved_backup)
  end

  if debugger then
    tprint(actual_saved_backup)
    tprint(num_actual_saved_backup)
  end

  if (actual_saved_backup and num_actual_saved_backup > 1) then
    local last_backup = {}
    for item in pairs(actual_saved_backup) do
      local redis_item = json.decode(ntop.getCache(item)) or {}
      if(redis_item and redis_item.last) then
        last_backup = {key = item, redis = redis_item}
        break
      end
    end

    if (last_backup.redis.instance ~= backup) then

      if debugger then
        tprint("Saving on cache with key: "..last_redis_key)
        tprint(backup)
      end 
      local string_to_save = json.encode({instance = backup, last = true})
      last_backup.redis.last = false
      ntop.setCache(last_backup.key, last_backup.redis)
      ntop.setCache(last_redis_key, string_to_save)
    end
  else 
      if debugger then
        tprint("Saving on cache with key: "..last_redis_key)
        tprint(backup)
      end
      local string_to_save = json.encode({instance = backup, last = true})
      ntop.setCache(last_redis_key, string_to_save)  
  end

end

-- ##############################################

-- @brief List all configurations backup.
function backup_config.list_backup()
  local num_actual_saved_backup = ntop.getKeysCache(saved_backup_key..".*") or {}

  local epoch_list = {}
  
  if (num_actual_saved_backup) then
    for item in pairs(num_actual_saved_backup) do
      table.insert(epoch_list, {epoch = item})
    end
  end

  return(epoch_list)
end

-- ##############################################

-- @brief Export configuration backup.
function backup_config.export_backup(epoch)

  if(epoch == nil or isEmptyString(epoch)) then
    return(-1)
  end

  local rc = rest_utils.consts.success.ok

  local num_actual_saved_backup = ntop.getKeysCache(saved_backup_key..".*") or {}

  if(num_actual_saved_backup) then
    
    
    local backup_to_restore_key = saved_backup_key.."."..epoch
    local redis_result = ntop.getCache(backup_to_restore_key)
    local backup_to_restore = json.decode(redis_result) or {}


    return(json.encode(backup_to_restore.instance, nil))
  end
end

-- ##############################################

if(action == "save") then
  backup_config.save_backup()
  rest_utils.answer(rest_utils.consts.success.ok)
elseif(action == "export") then
  backup_config.export_backup()
elseif(action == "list") then
  backup_config.list_backup()
end

-- ##############################################

return backup_config
