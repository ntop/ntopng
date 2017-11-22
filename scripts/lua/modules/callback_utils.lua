--
-- (C) 2017 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_aggregation_utils"
local os_utils = require "os_utils"

local callback_utils = {}

-- ########################################################

function callback_utils.print(file, line, message)
   print("["..file.."]:["..line.."] "..message)
end

-- ########################################################

-- Iterates available interfaces, excluding PCAP interfaces.
-- Each valid interface is select-ed and passed to the callback.
function callback_utils.foreachInterface(ifnames, condition, callback)
   for _,_ifname in pairs(ifnames) do
      interface.select(_ifname)
      local ifstats = interface.getStats()

      if condition == nil or condition(ifstats.id) then
	 if((ifstats.type ~= "pcap dump") and (ifstats.type ~= "unknown")) then
	    if callback(_ifname, ifstats, false) == false then
	       return false
	    end
	 end
      end
   end

   return true
end

-- ########################################################

-- Iterates each active host on the ifname interface.
-- Each host is passed to the callback with some more information.
function callback_utils.foreachLocalHost(ifname, deadline, callback)
   local hostbase

   interface.select(ifname)

   local hosts_stats = interface.getLocalHostsInfo(false)

   if hosts_stats == nil then
      hosts_stats = {hosts = {}}
   end

   hosts_stats = hosts_stats["hosts"]

   for hostname, hoststats in pairs(hosts_stats) do
      local host = interface.getHostInfo(hostname)

      if ((deadline ~= nil) and (os.time() >= deadline)) then
         -- Out of time
         return false
      end

      if host ~= nil then
         if(host.localhost) then
            local keypath = getPathFromKey(hostname)
            hostbase = os_utils.fixPath(dirs.workingdir .. "/" .. getInterfaceId(ifname) .. "/rrd/" .. keypath)

            if(not(ntop.exists(hostbase))) then
               ntop.mkdir(hostbase)
            end
         end

         if callback(hostname, host--[[hostinfo]], hostbase--[[base RRD host directory]]) == false then
            return false
         end
      end
   end

   return true
end

-- Iterates each device on the ifname interface.
-- Each device is passed to the callback with some more information.
function callback_utils.foreachDevice(ifname, deadline, callback)
   interface.select(ifname)

   local devices_stats = interface.getMacsInfo()
   if devices_stats == nil or devices_stats["macs"] == nil then
      devices_stats = {macs = {}}
   end

   for devicename, devicestats in pairs(devices_stats["macs"]) do
      devicename = hostinfo2hostkey(devicestats) -- make devicename the combination of mac address and vlan

      if ((deadline ~= nil) and (os.time() >= deadline)) then
         -- Out of time
         return false
      end

      local keypath = getPathFromKey(devicename)
      local devicebase = os_utils.fixPath(dirs.workingdir .. "/" .. getInterfaceId(ifname) .. "/rrd/" .. keypath)

      if(not(ntop.exists(devicebase))) then
	 ntop.mkdir(devicebase)
      end

      if callback(devicename, devicestats, devicebase) == false then
	 return false
      end
   end

   return true
end

-- ########################################################

function callback_utils.harverstExpiredMySQLFlows(ifname, mysql_retention, verbose)
   interface.select(ifname)

   local dbtables = {"flowsv4", "flowsv6"}
   if useAggregatedFlows() then
      dbtables[#dbtables+1] = "aggrflowsv4"
      dbtables[#dbtables+1] = "aggrflowsv6"
   end

   for _, tb in pairs(dbtables) do
      local sql = "DELETE FROM "..tb.." where FIRST_SWITCHED < "..mysql_retention
      sql = sql.." AND (INTERFACE_ID = "..getInterfaceId(ifname)..")"
      sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."' OR NTOPNG_INSTANCE_NAME IS NULL OR NTOPNG_INSTANCE_NAME='')"
      interface.execSQLQuery(sql)
      if(verbose) then io.write(sql.."\n") end
   end
end

-- ########################################################

function callback_utils.harverstOldRRDFiles(ifname)
   -- currently this is only implemented for old devices files. It should actually be implemented for other rrds as well
   local rrd_max_days = ntop.getPref("ntopng.prefs.rrd_files_retention")
   if isEmptyString(rrd_max_days) then rrd_max_days = 30 end

   ntop.deleteOldRRDs(getInterfaceId(ifname), tonumber(rrd_max_days) * 60 * 60 * 24)
end

-- ########################################################

return callback_utils
