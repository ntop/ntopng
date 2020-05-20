--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local prefs_dump_utils = require "prefs_dump_utils"

require "lua_utils"
local ts_dump = require "ts_min_dump_utils"
local ts_utils = require("ts_utils_core")

local prefs_changed = ntop.getCache("ntopng.prefs_changed")

if(prefs_changed == "true") then
   -- First delete prefs_changed then dump data
   ntop.delCache("ntopng.prefs_changed")
   prefs_dump_utils.savePrefsToDisk()
end

local ifstats = interface.getStats()
local when = os.time()

-- Dump periodic activities duration if the telementry timeseries preference is enabled
if ntop.getPref("ntopng.prefs.internals_rrd_creation") == "1" then
   ts_dump.update_internals_periodic_activities_stats(when, ifstats, false)
end

if(ntop.getPref("ntopng.prefs.interface_rrd_creation") ~= "0") then
   ts_utils.append("iface:alerts_stats", {ifid=getSystemInterfaceId(), engaged_alerts=ifstats.num_alerts_engaged, dropped_alerts=ifstats.num_dropped_alerts}, when)
end

-- Run minute scripts
ntop.checkSystemScriptsMin()
