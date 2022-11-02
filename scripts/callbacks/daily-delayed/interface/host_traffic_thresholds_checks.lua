--
-- (C) 2019-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local threshold_rules = require "host_threshold_check_rules"

local ifstats   = interface.getStats()
local frequency = "daily" -- daily checks

threshold_rules.check_threshold_rules(ifstats.name, ifstats.id,	frequency)