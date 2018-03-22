--
-- (C) 2014-18 - ntop.org
--

-- This file contains the description of all functions
-- used to serialize ntopng runtime preferences to disk
-- or restore them from disk

local os_utils = require "os_utils"

local prefs_dump_utils = {}

-- ###########################################

function prefs_dump_utils.savePrefsToDisk()
   local dirs = ntop.getDirs()
   local where = os_utils.fixPath(dirs.workingdir.."/runtimeprefs.json")

   local patterns = {"ntopng.prefs.*", "ntopng.user.*"}

   local out = {}
   for _, pattern in pairs(patterns) do
      local keys = ntop.getKeysCache(pattern)

      for k in pairs(keys or {}) do
	 out[k] = ntop.dumpCache(k)
      end
   end

   local json = require("dkjson")
   local dump = json.encode(out, nil, 1)

   local file = io.open(where, "w")
   if(file ~= nil) then
      file:write(dump)
      file:close()
   end
end

-- ###########################################

function prefs_dump_utils.readPrefsFromDisk()
   local dirs = ntop.getDirs()
   local where = os_utils.fixPath(dirs.workingdir.."/runtimeprefs.json")
   local file = io.open(where, "r")

   if(file ~= nil) then
      local dump = file:read()
      file:close()

      local json = require("dkjson")
      local restore = json.decode(dump, 1, nil)

      for k,v in pairs(restore or {}) do
	 --print(k.." = " .. v .. "\n")
	 ntop.restoreCache(k,v)
      end
   end
end

return prefs_dump_utils
