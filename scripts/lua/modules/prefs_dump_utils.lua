--
-- (C) 2014-20 - ntop.org
--

-- This file contains the description of all functions
-- used to serialize ntopng runtime preferences to disk
-- or restore them from disk
local dirs = ntop.getDirs()

local os_utils = require "os_utils"
local prefs_reload_utils = require "prefs_reload_utils"
local prefs_factory_reset_utils = require "prefs_factory_reset_utils"
local json = require("dkjson")

local prefs_dump_utils = {}

-- 00000600CB7634C0FA2A9E49 is the dump for ""
local empty_string_dump = "00000600CB7634C0FA2A9E49"

-- ###########################################

local patterns = {"ntopng.prefs.*", "ntopng.user.*"}

-- Path of the file used when doing periodic dumps of redis preferences to file
local dump_prefs_to_disk_file_path = os_utils.fixPath(dirs.workingdir.."/runtimeprefs.json")

-- Path of the file used when importing preferences from the UI
local import_prefs_file_path = os_utils.fixPath(dirs.workingdir.."/import_runtimeprefs.json")

-- ###########################################

local debug = false

-- ###########################################

-- @brief Dumps all preferences and user keys in a lua table
-- @return The lua table with all the dumped keys
function prefs_dump_utils.build_prefs_dump_table()
   local out = {}

   for _, pattern in pairs(patterns) do
      -- ntop.getKeysCache returns all the redis keys
      -- matching the given patter and SKIPS the in-memory
      -- cache implemented in class Redis.
      local keys = ntop.getKeysCache(pattern)

      for k in pairs(keys or {}) do
	 local dump = ntop.dumpCache(k)
	 if dump ~= empty_string_dump then
	    out[k] = dump
	 end
      end
   end

   return out
end

-- ###########################################

-- @brief Writes a lua table with dumped preferences and user keys to file
-- @param prefs_dump_table A lua table generated with `prefs_dump_utils.build_prefs_dump_table()`
-- @param file_path The full path to the destination file
-- @return True on success, false on failure
function prefs_dump_utils.write_prefs_dump_table_to_file(prefs_dump_table, file_path)
   local dump = json.encode(prefs_dump_table)

   local file,err = io.open(file_path, "w")
   if file then
      file:write(dump)
      file:close()
      return true
   else
      print("[ERROR] Unable to write file "..where..": "..err.."\n")
   end

   return false
end

-- ###########################################

-- @brief Writes a preferences dump table to file
function prefs_dump_utils.import_prefs_to_disk(prefs_dump_table)
   -- Do the actual dump
   local where = import_prefs_file_path
   return prefs_dump_utils.write_prefs_dump_table_to_file(prefs_dump_table, where)
end

-- ###########################################

-- @brief Checks if periodic preferences dump is enabled and possibly dump preferences to disk
function prefs_dump_utils.check_dump_prefs_to_disk() 
  if not prefs_reload_utils.is_dump_prefs_to_disk_requested() then
      -- nothing to do
      return
   end

   -- Now do the actual dump
   local where = dump_prefs_to_disk_file_path

   local out = prefs_dump_utils.build_prefs_dump_table()
   prefs_dump_utils.write_prefs_dump_table_to_file(out, where)
end

-- ###########################################

-- @brief Deletes all the existing keys matching preferences and user patterns
local function delete_all_keys()
   for _, pattern in pairs(patterns) do
      local keys = ntop.getKeysCache(pattern)
      for k, _ in pairs(keys or {}) do
	 ntop.delCache(k)
      end
   end
end

-- ###########################################

-- @brief Restores preferences using preferences dump file located at `file_path`
function prefs_dump_utils.restore_prefs_file(file_path)
   local file = io.open(file_path, "r")

   if(file ~= nil) then
      local dump = file:read()
      file:close()

      if(dump == nil) then
	 return
      end

      -- To make sure the restore puts all keys in a consistent state,
      -- before doing the actual restore, all the existing keys matching the bakcup/restore patterns
      -- are deleted.
      -- Failing to do this delete could result in inconsistent redis state as:
      --   1. There could be redis keys not yet backed up to file (backup is done at most once every few seconds)
      --   2. Redis keys not backed up to file could rely/depends on other keys that won't be restored.
      delete_all_keys()

      local json = require("dkjson")
      local restore = json.decode(dump, 1, nil)

      for k,v in pairs(restore or {}) do
	 --print(k.." = " .. v .. "\n")

	 if(v == empty_string_dump) then
	    ntop.delCache(k)
	    if(debug) then io.write("[RESTORE] Deleting empty value for "..k.."\n") end
	 else
	    if(debug) then io.write("[RESTORE] "..k.."="..v.."\n") end
	    ntop.restoreCache(k,v)
	 end
      end

      -- Necessary to reload all the restored and deleted preferences
      ntop.reloadPreferences(true --[[ also reset Redis defaults (e.g., admin user name, group, password) --]])
   end
end

-- ###########################################

function prefs_dump_utils.check_restore_prefs_from_disk()
   -- First, check if a preferences file has been imported via UI.
   -- If this file has been imported, not it is time to load it
   local where = import_prefs_file_path

   if ntop.exists(where) then
      -- Restore the file
      prefs_dump_utils.restore_prefs_file(where)

      -- Cleanup after restore. Cleanup includes both the imported file
      -- and the file possibly created when doing periodic pref fumps
      os.remove(import_prefs_file_path)
      os.remove(dump_prefs_to_disk_file_path)

      -- Done, leave
      return
   end

   -- If there there was no preference file imported from the UI.
   -- So we check if the periodic preferences dump to disk is enabled
   -- and possibly do the import
   if not prefs_reload_utils.is_dump_prefs_to_disk_enabled() then
      -- nothing to do
      return
   end

   where = dump_prefs_to_disk_file_path
   if ntop.exists(where) then
      prefs_dump_utils.restore_prefs_file(where)
   end
end

-- ###########################################

-- @brief Perform a factory reset, if requested.
--        NOTE: must be performed right after the startup of ntopng
function prefs_dump_utils.check_prefs_factory_reset()
   if prefs_factory_reset_utils.is_prefs_factory_reset_requested() then
      -- Delete all the configuration keys
      delete_all_keys()

      -- Necessary as all the preferences have been deleted: defaults will be reloaded
      ntop.reloadPreferences(true --[[also reset Redis defaults (e..g, admin user name, group, password) --]])

      -- Clear the pending request
      prefs_factory_reset_utils.clear_prefs_factory_reset_request()
   end
end

return prefs_dump_utils
