--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if (ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
  require("5min")

  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
  require "snmp_utils"
end

require "lua_utils"
require "graph_utils"
local callback_utils = require "callback_utils"

local when = os.time()
local verbose = ntop.verboseTrace()

-- ########################################################

local snmp_devices_rrd_creation = ntop.getCache("ntopng.prefs.snmp_devices_rrd_creation")

if(tostring(snmp_devices_rrd_creation) == "1" and ntop.isEnterprise() == false) then
   snmp_devices_rrd_creation = "0"
end

-- ########################################################

local ifnames = interface.getIfNames()

-- ########################################################

-- This must be placed at the end of the script
if(tostring(snmp_devices_rrd_creation) == "1") then
  -- We must complete within the 5 minutes
  local time_threshold = when - (when % 300) + 300

  callback_utils.foreachInterface(ifnames, verbose, function(_ifname, ifstats)
    snmp_update_rrds(ifstats.id, time_threshold, verbose)
  end)
end
