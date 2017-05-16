--
-- (C) 2017 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_aggregation_utils"

local callback_utils = {}

-- ########################################################

function callback_utils.print(file, line, message)
   print("["..file.."]:["..line.."] "..message)
end

-- ########################################################

-- Iterates available interfaces, excluding PCAP interfaces.
-- Each valid interface is select-ed and passed to the callback.
function callback_utils.foreachInterface(ifnames, verbose, callback)
  for _,_ifname in pairs(ifnames) do
    interface.select(_ifname)
    ifstats = interface.getStats()

    if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."]===============================\n["..__FILE__()..":"..__LINE__().."] Processing interface " .. _ifname .. " ["..ifstats.id.."]\n") end

    if((ifstats.type ~= "pcap dump") and (ifstats.type ~= "unknown")) then
      if callback(_ifname, ifstats, verbose) == false then
         return false
      end
    end
  end

  return true
end

-- ########################################################

-- Iterates each active host on the ifname interface.
-- Each host is passed to the callback with some more information.
function callback_utils.foreachHost(ifname, verbose, localHostsOnly, callback, deadline)
   local hostbase

   interface.select(ifname)

   if(localHostsOnly) then
      hosts_stats = interface.getLocalHostsInfo(false)
   else
      hosts_stats = interface.getHostsInfo(false)
   end

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

      if(host == nil) then
         if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] NULL host "..hostname.." !!!!\n") end
      else
         if(verbose) then
            print ("["..__FILE__()..":"..__LINE__().."] [" .. hostname .. "][local: ")
            print(tostring(host["localhost"]))
            print("]" .. (hoststats["bytes.sent"]+hoststats["bytes.rcvd"]) .. "]\n")
         end
	 
         if(host.localhost) then
            local keypath = getPathFromKey(hostname)
            hostbase = fixPath(dirs.workingdir .. "/" .. ifstats.id .. "/rrd/" .. keypath)

            if(not(ntop.exists(hostbase))) then
               if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Creating base directory ", hostbase, '\n') end
               ntop.mkdir(hostbase)
            end
         else
            hostbase = nil
         end

         if callback(hostname, host--[[hostinfo]], hostbase--[[base RRD host directory]], verbose) == false then
            return false
         end
      end
   end

   return true
end

-- ########################################################

-- Creates RRD with local hosts activity.
-- This is designed to be used as the *callback* parameter of callback_utils.foreachHost
-- TODO: host is not used so it is useless to call this function through a callback that
-- retrieves it via getHostInfo every time
function callback_utils.saveLocalHostsActivity(hostname, host--[[hostinfo]], hostbase, verbose)
   if host.localhost then
      local actStats = interface.getHostActivity(hostname)
      if actStats then
         local hostsbase = fixPath(hostbase .. "/activity")
         if(not(ntop.exists(hostsbase))) then
            if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Creating host activity directory ", hostsbase, '\n') end
            ntop.mkdir(hostsbase)
         end

         for act, val in pairs(actStats) do
            name = fixPath(hostsbase .. "/" .. act .. ".rrd")

            -- up, down, background bytes
            createActivityRRDCounter(name, verbose)
            ntop.rrd_update(name, "N:"..tolongint(val.up) .. ":" .. tolongint(val.down) .. ":" .. tolongint(val.background))

            if(verbose) then
               print("["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..' ['..val.up.."/"..val.down.."/"..val.background..']\n')
            end
         end
      end
   end
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

return callback_utils
