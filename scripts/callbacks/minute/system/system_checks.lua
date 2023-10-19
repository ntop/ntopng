--
-- (C) 2019-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local ts_dump = require "ts_min_dump_utils"
local checks = require "checks"

-- #################################################################
-- Just like for local_network_checks.lua, here periodic system 
-- checks are executed with the right granularity
-- #################################################################
--
-- The following checks are loaded
--
-- /var/lib/ntopng/scripts/callbacks/system/system/ids_ips_log.lua
-- /var/lib/ntopng/scripts/callbacks/system/system/dropped_alerts.lua
-- /var/lib/ntopng/scripts/callbacks/system/system/periodic_activity_not_executed.lua
-- /var/lib/ntopng/scripts/callbacks/system/system/clickhouse_monitor.lua
-- /var/lib/ntopng/scripts/callbacks/system/system/slow_periodic_activity.lua
--
-- #################################################################

local checks_var = {
   ifid = nil,
   system_ts_enabled = nil,
   system_config = nil,
   available_modules = nil,
   configset = nil,
   do_benchmark = false,
   do_print_benchmark = false
}

local granularity = "min"
local do_trace = false

-- #################################################################

checks.systemChecks(granularity, checks_var, do_trace)
