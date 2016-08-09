--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
json = require("dkjson")

--sendHTTPHeader('text/html; charset=iso-8859-1')
sendHTTPHeader('application/json')

function dumpInterfaceStats(interface_name)
   interface.select(interface_name)

   local ifstats = interface.getStats()
   local ifstats = aggregateInterfaceStats(ifstats)

   local stats = interface.getFlowsStats()

   local res = {}
   if(ifstats ~= nil) then
      uptime = ntop.getUptime()
      prefs = ntop.getPrefs()

      -- Round up
      hosts_pctg = math.floor(1+((ifstats.hosts*100)/prefs.max_num_hosts))
      flows_pctg = math.floor(1+((ifstats.flows*100)/prefs.max_num_flows))

      res["ifname"]  = string.gsub(interface_name, "\\", "\\\\")
      res["packets"] = ifstats.packets
      res["bytes"]   = ifstats.bytes
      res["drops"]   = ifstats.drops

      if prefs.are_alerts_enabled == true then
	 res["alerts"] = interface.getNumQueuedAlerts()
      end

      res["num_flows"]  = ifstats.flows
      res["num_hosts"]  = ifstats.hosts
      res["epoch"]      = os.time()
      res["uptime"]     = secondsToTime(uptime)
      res["hosts_pctg"] = hosts_pctg
      res["flows_pctg"] = flows_pctg
      res["remote_pps"] = ifstats.remote_pps
      res["remote_bps"] = ifstats.remote_bps
      res["is_view"]    = ifstats.isView

      res["local2remote"] = ifstats["localstats"]["bytes"]["local2remote"]
      res["remote2local"] = ifstats["localstats"]["bytes"]["remote2local"]

      res["tcpPacketStats"] = {}
      res["tcpPacketStats"]["retransmissions"] = ifstats.tcpPacketStats.retransmissions
      res["tcpPacketStats"]["out_of_order"]    = ifstats.tcpPacketStats.out_of_order
      res["tcpPacketStats"]["lost"]            = ifstats.tcpPacketStats.lost
      

      if(ifstats["bridge.device_a"] ~= nil) then
	 res["a_to_b_in_pkts"]       = ifstats["bridge.a_to_b.in_pkts"]
	 res["a_to_b_in_bytes"]      = ifstats["bridge.a_to_b.in_bytes"]
	 res["a_to_b_out_pkts"]      = ifstats["bridge.a_to_b.out_pkts"]
	 res["a_to_b_out_bytes"]     = ifstats["bridge.a_to_b.out_bytes"]
	 res["a_to_b_filtered_pkts"] = ifstats["bridge.a_to_b.filtered_pkts"]
	 res["a_to_b_shaped_pkts"]   = ifstats["bridge.a_to_b.shaped_pkts"]

	 res["b_to_a_in_pkts"]       = ifstats["bridge.b_to_a.in_pkts"]
	 res["b_to_a_in_bytes"]      = ifstats["bridge.b_to_a.in_bytes"]
	 res["b_to_a_out_pkts"]      = ifstats["bridge.b_to_a.out_pkts"]
	 res["b_to_a_out_bytes"]     = ifstats["bridge.b_to_a.out_bytes"]
	 res["b_to_a_filtered_pkts"] = ifstats["bridge.b_to_a.filtered_pkts"]
	 res["b_to_a_shaped_pkts"]   = ifstats["bridge.b_to_a.shaped_pkts"]

	 res["a_to_b_num_pkts_send_buffer_full"] = ifstats["bridge.a_to_b.num_pkts_send_buffer_full"]
	 res["a_to_b_num_pkts_send_error"]       = ifstats["bridge.a_to_b.num_pkts_send_error"]
	 res["b_to_a_num_pkts_send_buffer_full"] = ifstats["bridge.b_to_a.num_pkts_send_buffer_full"]
	 res["b_to_a_num_pkts_send_error"]       = ifstats["bridge.b_to_a.num_pkts_send_error"] 
      end

      if(ifstats["profiles"] ~= nil) then
	 res["profiles"] = ifstats["profiles"]
      end

      res["breed"] = stats["breeds"]
   end
   return res
end

-- ###############################

local res = {}
if(_GET["ifname"] == "all") then
   local names = interface.getIfNames()
   local n = 1
   local sortedKeys = getKeysSortedByValue(names, function(a, b) return a < b end)
   for k,v in ipairs(sortedKeys) do
      res[n] = dumpInterfaceStats(names[v])
      n = n + 1
   end
else
   res = dumpInterfaceStats(ifname)
end
print(json.encode(res, nil, 1))
