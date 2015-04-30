--
-- (C) 2013 - ntop.org
--


dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "alert_utils"

if (ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
  require("daily")
end

-- Delete JSON files older than a 30 days
-- TODO: make 30 configurable
harvestJSONTopTalkers(30)

-- Scan "day" alerts
scanAlerts("day")

local debug = false
local delete_keys = true

begin = os.clock()
t = os.time()-86400

if((_GET ~= nil) and (_GET["debug"] ~= nil)) then
   debug = true
   t = t + 86400
end

if(debug) then sendHTTPHeader('text/plain') end

when = os.date("%y%m%d", t)

ifnames = interface.getIfNames()
for _,_ifname in pairs(ifnames) do
   interface.select(purifyInterfaceName(_ifname))
   interface.flushHostContacts()
   ntop.deleteMinuteStatsOlderThan(_ifname, 365)

   hosts_stats = interface.getHostsInfo()
   for key, value in pairs(hosts_stats) do
     interface.resetPeriodicStats(key, value["vlan"])
   end
   if (interface.getInterfaceDumpDiskPolicy() == true) then
     ntop.deleteDumpFiles(interface.name2id(_ifname))
   end
end


-- os.execute("sleep 300")
ntop.dumpDailyStats(when)

-- redis-cli KEYS "131129|*" | xargs redis-cli DEL
