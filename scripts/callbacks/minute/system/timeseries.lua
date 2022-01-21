--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

local scripts_triggers = require "scripts_triggers"
local prefs_dump_utils = require "prefs_dump_utils"
local cpu_utils = require("cpu_utils")
local ts_utils = require("ts_utils_core")

local system_host_stats = cpu_utils.systemHostStats()
local ifstats = interface.getStats()
local when = os.time()

-- Check and possibly dump preferences to a file
prefs_dump_utils.check_dump_prefs_to_disk()

-- #####################################

-- Dump periodic activities duration if the telementry timeseries preference is enabled
if scripts_triggers.isRrdInterfaceCreation() then
   local ts_dump = require "ts_min_dump_utils"

   ts_dump.update_internals_periodic_activities_stats(when, ifstats, false)
end

-- #####################################

if scripts_triggers.isRrdInterfaceCreation() then
   if areAlertsEnabled() then
      ts_utils.append("iface:engaged_alerts", {ifid=getSystemInterfaceId(), engaged_alerts=ifstats.num_alerts_engaged}, when)
      ts_utils.append("iface:dropped_alerts", {ifid=getSystemInterfaceId(), dropped_alerts=ifstats.num_dropped_alerts}, when)
   end
end

-- #####################################

if cpu_utils.processTimeseriesEnabled() then
   ts_utils.append("process:num_alerts", {
      ifid = getSystemInterfaceId(),
      dropped_alerts = system_host_stats.dropped_alerts or 0,
      written_alerts = system_host_stats.written_alerts or 0,
      alerts_queries = system_host_stats.alerts_queries or 0
   }, when, verbose)

   -- #####################################

   if((system_host_stats.mem_ntopng_resident ~= nil) and (system_host_stats.mem_ntopng_virtual ~= nil)) then
      ts_utils.append("process:resident_memory", {
         ifid = getSystemInterfaceId(),
         resident_bytes = system_host_stats.mem_ntopng_resident * 1024,
      }, when, verbose)
   end
end

-- #####################################
