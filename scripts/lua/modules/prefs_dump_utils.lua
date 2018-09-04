--
-- (C) 2014-18 - ntop.org
--

-- This file contains the description of all functions
-- used to serialize ntopng runtime preferences to disk
-- or restore them from disk

local os_utils = require "os_utils"

local prefs_dump_utils = {}

-- 00000600CB7634C0FA2A9E49 is the dump for ""
local empty_string_dump = "00000600CB7634C0FA2A9E49"

-- ###########################################

local debug = false

function prefs_dump_utils.savePrefsToDisk()
   local dirs = ntop.getDirs()
   local where = os_utils.fixPath(dirs.workingdir.."/runtimeprefs.json")

   local patterns = {"ntopng.prefs.*", "ntopng.user.*"}

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
	 elseif pattern == "ntopng.prefs.*" then
	    -- Empty preferences can be found in redis due to
	    -- previous implementations. Currently, empty preferences
	    -- only stay in the in-memory cache implemented in class Redis
	    -- (Redis::addToCache) and there's no longer need to have them
	    -- written to redis. See Redis::isCacheable for the whole list
	    -- of keys that are cached internally
	    ntop.delCache(k)
	 end
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

	 if(v == empty_string_dump) then
	    ntop.delCache(k)
	    if(debug) then io.write("[RESTORE] Deleting empty value for "..k.."\n") end
	 else 
	    if(debug) then io.write("[RESTORE] "..k.."="..v.."\n") end
	    ntop.restoreCache(k,v)
	 end
      end
   end
end

return prefs_dump_utils
