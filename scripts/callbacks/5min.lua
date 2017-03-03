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

local when = os.time()
local verbose = ntop.verboseTrace()

-- ########################################################

local snmp_devices_rrd_creation = ntop.getCache("ntopng.prefs.snmp_devices_rrd_creation")
local snmp_to_dump = {}

if(tostring(snmp_devices_rrd_creation) == "1" and ntop.isEnterprise() == false) then
   snmp_devices_rrd_creation = "0"
end

-- ########################################################

local ifnames = interface.getIfNames()

-- Save SNMP stats every 5 minutes
for _,_ifname in pairs(ifnames) do
  interface.select(_ifname)
  ifstats = interface.getStats()

  if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."]===============================\n["..__FILE__()..":"..__LINE__().."] Processing interface " .. _ifname .. " ["..ifstats.id.."]\n") end

  if((ifstats.type ~= "pcap dump") and (ifstats.type ~= "unknown")) then

    -- SNMP devices
    if(tostring(snmp_devices_rrd_creation) == "1") then
      snmp_to_dump[#snmp_to_dump + 1] = ifstats.id
    end
  end
end

-- ########################################################

-- Check for SNMP to dump
local time_threshold = when - (when % 300) + 300

for _, ifid in pairs(snmp_to_dump) do
   -- We must complete within the minute
   snmp_update_rrds(ifid, time_threshold, verbose)
end
