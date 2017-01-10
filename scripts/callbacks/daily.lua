--
-- (C) 2013-17 - ntop.org
--


dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "alert_utils"
require "blacklist_utils"

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
   require("daily")
end

-- Delete JSON files older than a 30 days
-- TODO: make 30 configurable
harvestJSONTopTalkers(30)

-- Scan "day" alerts
for _, ifname in pairs(interface.getIfNames()) do
   scanAlerts("day", ifname)
end

local debug = false
local delete_keys = true

function harverstExpiredMySQLFlows(ifname, mysql_retention)
   sql = "DELETE FROM flowsv4 where FIRST_SWITCHED < "..mysql_retention
   sql = sql.." AND (INTERFACE_ID = "..getInterfaceId(ifname)..")"
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."' OR NTOPNG_INSTANCE_NAME IS NULL)"
   interface.execSQLQuery(sql)
   if(debug) then io.write(sql.."\n") end

   sql = "DELETE FROM flowsv6 where FIRST_SWITCHED < "..mysql_retention
   sql = sql.." AND (INTERFACE_ID = "..getInterfaceId(ifname)..")"
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

minute_top_talkers_retention = ntop.getCache("ntopng.prefs.minute_top_talkers_retention")
if((minute_top_talkers_retention == nil) or (minute_top_talkers_retention == "")) then minute_top_talkers_retention = "365" end

ifnames = interface.getIfNames()
for _,_ifname in pairs(ifnames) do
   interface.select(_ifname)
   interface_id = getInterfaceId(_ifname)

   ntop.deleteMinuteStatsOlderThan(interface_id, tonumber(minute_top_talkers_retention))

   harverstExpiredMySQLFlows(_ifname, mysql_retention)

   hosts_stats = interface.getHostsInfo(false --[[ don't show details --]])
   hosts_stats = hosts_stats["hosts"]

   for key, value in pairs(hosts_stats) do
      interface.resetPeriodicStats(key, value["vlan"])
   end

   if(interface.getInterfaceDumpDiskPolicy() == true) then
      ntop.deleteDumpFiles(interface_id)
   end
end


loadHostBlackList()
