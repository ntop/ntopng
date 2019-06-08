--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local prefs_dump_utils = require "prefs_dump_utils"

require "lua_utils"
local ts_utils = require("ts_utils_core")
local system_scripts = require("system_scripts_utils")
require("ts_minute")

local prefs_changed = ntop.getCache("ntopng.prefs_changed")

if(prefs_changed == "true") then
   -- First delete prefs_changed then dump data
   ntop.delCache("ntopng.prefs_changed")
   prefs_dump_utils.savePrefsToDisk()
end

local system_host_stats = ntop.systemHostStat()
local when = os.time()

if((system_host_stats.mem_ntopng_resident ~= nil) and
      (system_host_stats.mem_ntopng_virtual ~= nil)) then
   ts_utils.append("process:memory", {
      resident_bytes = system_host_stats.mem_ntopng_resident * 1024,
      virtual_bytes = system_host_stats.mem_ntopng_virtual * 1024,
   }, when, verbose)
end

system_scripts.runTask("minute", when)
