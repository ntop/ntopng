--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local checks = require "checks"

-- #################################################################
-- Just like for local_network_checks.lua, here periodic system 
-- checks are executed with the right granularity
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

local granularity = "5mins" -- See alert_consts.alerts_granularities
local do_trace = false

-- #################################################################

-- TODO: Remove ping from the active monitoring alert. Right now
--       the ping is done by the script active_monitoring.lua that
--       is the script managing the checks of the active monitoring.
--       Separate them into two scripts, uno that executes the pings
--       and the other one that executes the checks.
checks.systemChecks(granularity, checks_var, do_trace)
