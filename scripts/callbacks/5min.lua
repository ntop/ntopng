--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
  require("5min")

  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
  require "snmp_utils"
end

require "lua_utils"
local rrd_dump = require "rrd_5min_dump_utils"
local callback_utils = require "callback_utils"

local when = os.time()
local verbose = ntop.verboseTrace()

-- We must complete within the 5 minutes
local time_threshold = when - (when % 300) + 300 - 10 -- safe margin

-- ########################################################

local config = rrd_dump.getConfig()
local ifnames = interface.getIfNames()

-- ########################################################

callback_utils.foreachInterface(ifnames, nil, function(_ifname, ifstats)
  rrd_dump.run_5min_dump(_ifname, ifstats, config, when, time_threshold, verbose)
end)

-- ########################################################

-- This must be placed at the end of the script
if(tostring(config.snmp_devices_rrd_creation) == "1") then
   snmp_update_rrds(time_threshold, verbose)
end
