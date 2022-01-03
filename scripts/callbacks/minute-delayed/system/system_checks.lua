--
-- (C) 2019-22 - ntop.org
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

local granularity = "min"
local do_trace = false

-- #################################################################

checks.systemChecks(granularity, checks_var, do_trace)
