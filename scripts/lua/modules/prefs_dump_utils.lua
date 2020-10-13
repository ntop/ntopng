--
-- (C) 2014-20 - ntop.org
--

-- This file contains the description of all functions
-- used to serialize ntopng runtime preferences to disk
-- or restore them from disk

local os_utils = require "os_utils"
local prefs_reload_utils = require "prefs_reload_utils"

local prefs_dump_utils = {}

-- 00000600CB7634C0FA2A9E49 is the dump for ""
local empty_string_dump = "00000600CB7634C0FA2A9E49"

-- ###########################################

local patterns = {"ntopng.prefs.*", "ntopng.user.*"}

-- ###########################################

local function set_admin_prefs()
   -- User admin is always an administrator, let's make sure serialized values are correct
   ntop.setCache("ntopng.user.admin.group", "administrator")
   ntop.setCache("ntopng.user.admin.allowed_nets", "0.0.0.0/0,::/0")
end

-- ###########################################

local debug = false

function prefs_dump_utils.check_dump_prefs_to_disk()
   if not prefs_reload_utils.is_dump_prefs_to_disk_requested() then
      -- nothing to do
      return
   end

   -- Now do the actual dump

   local dirs = ntop.getDirs()
   local where = os_utils.fixPath(dirs.workingdir.."/runtimeprefs.json")

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

   local json = require("dkjson")
   local dump = json.encode(out, nil, 1)

   local file,err = io.open(where, "w")
   if(file ~= nil) then
      file:write(dump)
      file:close()
   else
      print("[ERROR] Unable to write file "..where..": "..err.."\n")
   end
end

-- ###########################################

function prefs_dump_utils.check_restore_prefs_from_disk()
   if not prefs_reload_utils.is_dump_prefs_to_disk_enabled() then
      -- nothing to do
      return
   end

   local dirs = ntop.getDirs()
   local where = os_utils.fixPath(dirs.workingdir.."/runtimeprefs.json")
   local file = io.open(where, "r")

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
      for _, pattern in pairs(patterns) do
	 local keys = ntop.getKeysCache(pattern)
	 for k, _ in pairs(keys or {}) do
	    ntop.delCache(k)
	 end
      end

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
   end

   set_admin_prefs()
end

return prefs_dump_utils
