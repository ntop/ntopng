--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')
--sendHTTPHeader('application/json')


function dumpInterfaceStats(interface_name)
   interface.select(interface_name)
   ifstats = aggregateInterfaceStats(interface.getStats())

   stats = interface.getFlowsStats()

   if(ifstats ~= nil) then
      uptime = ntop.getUptime()
      prefs = ntop.getPrefs()

      -- Round up
      hosts_pctg = math.floor(1+((ifstats.hosts*100)/prefs.max_num_hosts))
      flows_pctg = math.floor(1+((ifstats.flows*100)/prefs.max_num_flows))

      print('\t{ "ifname": "'.. interface_name..'", "packets": '.. ifstats.packets .. ', "bytes": ' .. ifstats.bytes .. ', "drops": ' .. ifstats.drops .. ', "alerts": '.. ntop.getNumQueuedAlerts() ..', "num_flows": '.. ifstats.flows .. ', "num_hosts": ' .. ifstats.hosts .. ', "epoch": ' .. os.time()..' , "uptime": " ' .. secondsToTime(uptime) .. '", "hosts_pctg": ' .. hosts_pctg .. ', "flows_pctg": ' .. flows_pctg)
      print(', "is_view": '..tostring(ifstats.isView))
      print(', "local2remote": '.. ifstats["localstats"]["bytes"]["local2remote"]..', "remote2local": '..ifstats["localstats"]["bytes"]["remote2local"])

      print(', "tcpPacketStats": { "retransmissions": '..tostring(ifstats.tcpPacketStats.retransmissions)..', "out_of_order": '..tostring(ifstats.tcpPacketStats.out_of_order)..', "lost":'..tostring(ifstats.tcpPacketStats.lost)..' }')

      if(ifstats["bridge.device_a"] ~= nil) then
	 print(', "a_to_b_in_pkts": '.. ifstats["bridge.a_to_b.in_pkts"])
	 print(', "a_to_b_in_bytes": '.. ifstats["bridge.a_to_b.in_bytes"])
	 print(', "a_to_b_out_pkts": '.. ifstats["bridge.a_to_b.out_pkts"])
	 print(', "a_to_b_out_bytes": '.. ifstats["bridge.a_to_b.out_bytes"])
	 print(', "a_to_b_filtered_pkts": '.. ifstats["bridge.a_to_b.filtered_pkts"])
	 print(', "a_to_b_shaped_pkts": '.. ifstats["bridge.a_to_b.shaped_pkts"])
	 print(', "b_to_a_in_pkts": '.. ifstats["bridge.b_to_a.in_pkts"])
	 print(', "b_to_a_in_bytes": '.. ifstats["bridge.b_to_a.in_bytes"])
	 print(', "b_to_a_out_pkts": '.. ifstats["bridge.b_to_a.out_pkts"])
	 print(', "b_to_a_out_bytes": '.. ifstats["bridge.b_to_a.out_bytes"])
	 print(', "b_to_a_filtered_pkts": '.. ifstats["bridge.b_to_a.filtered_pkts"])
	 print(', "b_to_a_shaped_pkts": '.. ifstats["bridge.b_to_a.shaped_pkts"])
	 print(', "a_to_b_num_pkts_send_buffer_full": '.. ifstats["bridge.a_to_b.num_pkts_send_buffer_full"])
	 print(', "a_to_b_num_pkts_send_error": '.. ifstats["bridge.a_to_b.num_pkts_send_error"])
	 print(', "b_to_a_num_pkts_send_buffer_full": '.. ifstats["bridge.b_to_a.num_pkts_send_buffer_full"])
	 print(', "b_to_a_num_pkts_send_error": '.. ifstats["bridge.b_to_a.num_pkts_send_error"])
      end

      if(ifstats["profiles"] ~= nil) then
        print(", \"profiles\": { ")
        num = 0
        for key, value in pairsByKeys(ifstats["profiles"], rev) do
	 if(num > 0) then
	    print(", ")
	 end
	 print(' "'..key..'": '..value)
	 num = num + 1
        end
        print(' }')
      end

      print(", \"breed\": { ")
      num = 0
      for key, value in pairsByKeys(stats["breeds"], rev) do
	 if(num > 0) then
	    print(", ")
	 end
	 print(' "'..key..'": '..value)
	 num = num + 1
      end
      print(' }')
      print(' }')
   else
      print('{ }')
   end
end

-- ###############################

if(_GET["ifname"] == "all") then
   names = interface.getIfNames()

   print("[\n")
   n = 0

   sortedKeys = getKeysSortedByValue(names, function(a, b) return a < b end)
   for k,v in ipairs(sortedKeys) do
      if(n > 0) then print(",\n") end
      dumpInterfaceStats(names[v])
      n = n + 1
   end
   print("\n]\n")
else
   dumpInterfaceStats(ifname)
end