--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local checks = require "checks"

-- #################################################################
-- Just like for local_network_checks.lua, here periodic snmp 
-- checks are executed with the right granularity
-- #################################################################

local checks_var = {
   ifid = nil,
   cur_granularity = nil,
   system_ts_enabled = nil,
   system_config = nil,
   snmp_device_entity = nil,
   pools_instance = nil,
   config_alerts = nil,
   available_modules = nil,
   configset = nil,
   do_benchmark = false,
   do_print_benchmark = false
}

local granularity = "5min"
local do_trace = false

-- #################################################################

checks.SNMPChecks(granularity, checks_var, do_trace)
