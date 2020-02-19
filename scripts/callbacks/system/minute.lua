--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local prefs_dump_utils = require "prefs_dump_utils"

require "lua_utils"
local ts_dump = require "ts_min_dump_utils"

local prefs_changed = ntop.getCache("ntopng.prefs_changed")

if(prefs_changed == "true") then
   -- First delete prefs_changed then dump data
   ntop.delCache("ntopng.prefs_changed")
   prefs_dump_utils.savePrefsToDisk()
end

-- Dump periodic activities duration
ts_dump.update_periodic_scripts_stats(os.time(), interface.getStats(), false)

-- Run minute scripts
ntop.checkSystemScriptsMin()
