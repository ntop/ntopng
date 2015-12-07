--
-- (C) 2013-15 - ntop.org
--


dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "alert_utils"

if(ntop.isPro()) then
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


function harverstExpiredMySQLFlows(ifname, mysql_retention)
   sql = "DELETE FROM flowsv4 where FIRST_SWITCHED < "..mysql_retention
   sql = sql.." AND (INTERFACE = '"..ifname.."' OR INTERFACE IS NULL)"
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."' OR NTOPNG_INSTANCE_NAME IS NULL)"
   interface.execSQLQuery(sql)
   if(debug) then io.write(sql.."\n") end

   sql = "DELETE FROM flowsv6 where FIRST_SWITCHED < "..mysql_retention
   sql = sql.." AND (INTERFACE = '"..ifname.."' OR INTERFACE IS NULL)"
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."' OR NTOPNG_INSTANCE_NAME IS NULL)"
   interface.execSQLQuery(sql)
   if(debug) then io.write(sql.."\n") end
end


begin = os.clock()
t = os.time()-86400

if((_GET ~= nil) and (_GET["debug"] ~= nil)) then
   debug = true
   t = t + 86400
end

if(debug) then sendHTTPHeader('text/plain') end

when = os.date("%y%m%d", t)

mysql_retention = ntop.getCache("ntopng.prefs.mysql_retention")
if((mysql_retention == nil) or (mysql_retention == "")) then mysql_retention = "30" end
mysql_retention = os.time() - 86400*tonumber(mysql_retention)

ifnames = interface.getIfNames()
for _,_ifname in pairs(ifnames) do
   interface.select(purifyInterfaceName(_ifname))
   interface_id = getInterfaceId(ifname)

   ntop.deleteMinuteStatsOlderThan(interface_id, 365)

   harverstExpiredMySQLFlows(_ifname, mysql_retention)

   hosts_stats = interface.getHostsInfo()

   for key, value in pairs(hosts_stats) do
      interface.resetPeriodicStats(key, value["vlan"])
   end

   if(interface.getInterfaceDumpDiskPolicy() == true) then
      ntop.deleteDumpFiles(interface_id)
   end
end

