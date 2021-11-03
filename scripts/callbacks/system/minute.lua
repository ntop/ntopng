--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/callbacks/system/?.lua;" .. package.path
   require('minute')
end

local scripts_triggers = require "scripts_triggers"
local prefs_dump_utils = require "prefs_dump_utils"

-- Check and possibly dump preferences to a file
prefs_dump_utils.check_dump_prefs_to_disk()

local ifstats = interface.getStats()
local when = os.time()

-- Dump periodic activities duration if the telementry timeseries preference is enabled
if scripts_triggers.isRrdInterfaceCreation() then
   local ts_dump = require "ts_min_dump_utils"

   ts_dump.update_internals_periodic_activities_stats(when, ifstats, false)
end

if scripts_triggers.isRrdInterfaceCreation() then
   local ts_utils = require("ts_utils_core")

   if areAlertsEnabled() then
      ts_utils.append("iface:engaged_alerts", {ifid=getSystemInterfaceId(), engaged_alerts=ifstats.num_alerts_engaged}, when)
      ts_utils.append("iface:dropped_alerts", {ifid=getSystemInterfaceId(), dropped_alerts=ifstats.num_dropped_alerts}, when)
   end
end

if ntop.isPro() then
   local drop_host_pool_utils = require "drop_host_pool_utils"

   drop_host_pool_utils.check_periodic_hosts_list()
   drop_host_pool_utils.check_pre_banned_hosts_to_add()
end   

-- Run minute scripts
ntop.checkSystemScriptsMin()
