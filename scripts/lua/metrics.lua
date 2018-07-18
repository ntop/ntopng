--
-- (C) 2017-18 - ntop.org
--
-- Prometeus integration script
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local callback_utils = require "callback_utils"

local verbose = false
local poll_interval = 60
local localHostsOnly = true

local now = tostring(os.time())

-- ##############################################################################

local function printElement(what, base_label, value, now)
   if((value ~= nil) and (value > 0)) then
      print(what.." {"..table.tconcat(base_label, "=", ", ", nil, '"').."} "..tostring(value).." "..now.."000\n")
   end
end

-- ##############################################################################

local function printHostSample(ifname, host, now)
   for k,v in pairs(host) do
      if((string.contains(k, "bytes")
	     or string.contains(k, "packets")
	     or string.contains(k, "throughput")
	     or string.starts(k, "tcp.")
	     or string.starts(k, "udp.")
	     or string.starts(k, "icmp.")
	     or string.starts(k, "other_ip.")
	     or string.starts(k, "flows.")
	     or string.starts(k, "num_")
	     or string.starts(k, "active_flows")
	     or string.starts(k, "queries_") -- DNS
	 ) and (
	       not(
		  string.starts(k, "last_")
		     or string.contains(k, "trend_")
	       )
	       )
      ) then
	 printElement("hosts", { ["ifname"] = ifname, ["ip"] = host["ip"], ["metric"] = "stats."..k }, v, now)
      end
   end
   
   if(host["ndpi"] ~= nil) then
      for protoname in pairs(host["ndpi"]) do
	 printElement("hosts", { ["ifname"] = ifname, ["ip"] = host["ip"], ["metric"] = "L7."..protoname..".bytes.sent" }, host["ndpi"][protoname]["bytes.sent"], now)
	 printElement("hosts", { ["ifname"] = ifname, ["ip"] = host["ip"], ["metric"] = "L7."..protoname..".bytes.rcvd" }, host["ndpi"][protoname]["bytes.rcvd"], now)
      end
   end
end

-- ##############################################################################

local function printInterfaceSample(ifname, now)
   local stats
   local metrics

   stats = interface.getStats()
   
   for k,v in pairs(stats["stats"]) do
      printElement("ifaces", { ["ifname"] = ifname, ["metric"] = "stats."..k }, v, now)
   end

   metrics = { "arp.requests", "arp.replies" }
   for _, k in pairs(metrics) do
      local v = stats[k]

      printElement("ifaces", { ["ifname"] = ifname, ["metric"] = "stats."..k }, v, now)
   end
   
   local ndpi = interface.getnDPIStats()["ndpi"]
   metrics = { "bytes.sent", "bytes.rcvd" }
   for protoname in pairs(ndpi) do
      for _,k in pairs(metrics) do
	 printElement("ifaces", { ["ifname"] = ifname, ["metric"] = "L7."..protoname.."."..k }, ndpi[protoname][k], now)
      end
   end

   local ases_stats = interface.getASesInfo("column_asn", 100000, 0, false, false)
   if(ases_stats ~= nil) then
      metrics = { "bytes.sent", "bytes.rcvd", "num_hosts" }
      for _,as in ipairs(ases_stats["ASes"]) do
	 for _, k in pairs(metrics) do	    
	    printElement("ifaces", { ["ifname"] = ifname, ["metric"] = "AS."..as["asn"].."."..k }, as[k], now)	    
	 end
      end
   end

   stats = interface.getNetworksStats()
   if(stats ~= nil) then
      for net,t in pairs(stats) do
	 metrics = { "egress", "inner" }
	 
	 for _,k in pairs(metrics) do
	    printElement("ifaces", { ["ifname"] = ifname, ["metric"] = "net."..net.."."..k }, t[k], now)
	 end
      end
   end
end

-- ##############################################################################

-- Note: currently prometheus does not seem to honor per-job X-Prometheus-Scrape-Timeout-Seconds
--~ local poll_interval = tonumber(_SERVER["X-Prometheus-Scrape-Timeout-Seconds"])

local when = os.time()
local time_threshold = when + poll_interval

sendHTTPContentTypeHeader('text/plain')

print[[
#HELP The traffic volume of an host relative to a specific protocol, in bytes
#TYPE counter
]]

local ifnames = interface.getIfNames()

callback_utils.foreachInterface(ifnames, nil, function(ifname, ifstats)
				   if(not(string.starts(ifname, "view:"))) then
				      local in_time

				      interface.select(ifname)
				      
				      in_time = callback_utils.foreachLocalHost(ifname, os.time() + 60,
										function (hostname, host)
										   printHostSample(ifname, host, now)
										end, time_threshold)
				      
				      printInterfaceSample(ifname, now)
				      if not in_time then
					 callback_utils.print(__FILE__(), __LINE__(),
							      "ERROR: Cannot complete prometheus metrics export in "..poll_interval.." seconds.")
					 return false
				      end
				   end
end)
