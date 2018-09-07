--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local prefs_dump_utils = require "prefs_dump_utils"
local prefs_changed = ntop.getCache("ntopng.prefs_changed")

if(prefs_changed == "true") then
   -- First delete prefs_changed then dump data
   ntop.delCache("ntopng.prefs_changed")
   prefs_dump_utils.savePrefsToDisk()
end

