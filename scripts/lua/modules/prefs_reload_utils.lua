--
-- (C) 2014-20 - ntop.org
--

local prefs_reload_utils = {}

-- ###########################################

-- Key used to determine if it is time to reload in-memory preferences.
-- This key is set by Redis.cpp, when a preference is changed.
-- NOTE: keep it in sync with ntop_defines.h PREFS_CHANGED
local prefs_changed_key = "ntopng.cache.prefs_changed"

-- Key used to enable periodic runtime preferences dump to file.
-- This key, disabled by default, can be enabled when ntopng is run on appliances
-- that don't feature a persistent Redis. In this case, it may be useful to dump
-- changed preferences to a file and to restore them during boot in boot.lua.
local dump_prefs_to_disk_key = "ntopng.prefs.dump_prefs_to_disk"

-- Key used to request the dump of runtime preferences to dump file.
-- Actual dump is performed in prefs_dump_utils.lua.
-- NOTE: This key is only set when dump_prefs_to_disk_key is enabled and thus the dump can be requested.
local prefs_dump_request_key = "ntopng.cache.prefs_dump_request"

-- ###########################################

function prefs_reload_utils.is_dump_prefs_to_disk_enabled()
   local prefs_to_disk = ntop.getCache(dump_prefs_to_disk_key)

   return prefs_to_disk == "1"
end

-- ###########################################

function prefs_reload_utils.is_dump_prefs_to_disk_requested()
   local dump_requested = ntop.getCache(prefs_dump_request_key)

   if dump_requested == "1" then      
      -- Delete before doing the dump to guarantee no other dump request will be lost
      ntop.delCache(prefs_dump_request_key)

      return true
   end

   return false
end

-- ###########################################

local function are_prefs_changed()
   local prefs_changed = ntop.getCache(prefs_changed_key)

   if prefs_changed == "1" then
      -- Make sure to delete BEFORE doing the actual reload
      -- To guarantee no reload gets missed
      ntop.delCache(prefs_changed_key)

      return true
   end

   return false
end

-- ###########################################

-- @brief Checks and possibly reload in-memory preferences from Redis
--        Reload is performed when Redis preferences are changed, to re-align them with in-memory preferences
function prefs_reload_utils.check_reload_prefs()
   if are_prefs_changed() then
      -- Do the actual reload
      ntop.reloadPreferences()

      -- Finally check if preferences dump to disk is enabled and,
      -- in that case, request for the dump
      if prefs_reload_utils.is_dump_prefs_to_disk_enabled() then
	 ntop.setCache(prefs_dump_request_key, "1")
      end
   end
end

-- ###########################################

return prefs_reload_utils
