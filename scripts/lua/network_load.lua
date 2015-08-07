--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')
--sendHTTPHeader('application/json')


function dumpInterfaceStats(interface_name)
   interface.select(interface_name)
   ifstats = interface.getStats()
   is_historical = interface.isHistoricalInterface(interface.name2id(interface_name))

   if(not(is_historical)) then
      stats = interface.getFlowsStats()
   end

   if(ifstats ~= nil) then
      uptime = ntop.getUptime()
      prefs = ntop.getPrefs()

      -- Round up
      hosts_pctg = math.floor(1+((ifstats.stats_hosts*100)/prefs.max_num_hosts))
      flows_pctg = math.floor(1+((ifstats.stats_flows*100)/prefs.max_num_flows))

      print('\t{ "ifname": "'.. interface_name..'", "packets": '.. ifstats.stats_packets .. ', "bytes": ' .. ifstats.stats_bytes .. ', "drops": ' .. ifstats.stats_drops .. ', "alerts": '.. ntop.getNumQueuedAlerts() ..', "num_flows": '.. ifstats.stats_flows .. ', "num_hosts": ' .. ifstats.stats_hosts .. ', "epoch": ' .. os.time()..' , "uptime": " ' .. secondsToTime(uptime) .. '", "hosts_pctg": ' .. hosts_pctg .. ', "flows_pctg": ' .. flows_pctg)

      print(', "local2remote": '.. ifstats["localstats"]["bytes"]["local2remote"]..', "remote2local": '..ifstats["localstats"]["bytes"]["remote2local"])

      if(ifstats["bridge.device_a"] ~= nil) then
	 print(', "a_to_b_in_pkts": '.. ifstats["bridge.a_to_b.in_pkts"])
	 print(', "a_to_b_out_pkts": '.. ifstats["bridge.a_to_b.out_pkts"])
	 print(', "a_to_b_filtered_pkts": '.. ifstats["bridge.a_to_b.filtered_pkts"])
	 print(', "b_to_a_in_pkts": '.. ifstats["bridge.b_to_a.in_pkts"])
	 print(', "b_to_a_out_pkts": '.. ifstats["bridge.b_to_a.out_pkts"])
	 print(', "b_to_a_filtered_pkts": '.. ifstats["bridge.b_to_a.filtered_pkts"])
      end

      if(is_historical) then
	 historical_stats = interface.getHistorical();
	 if (historical_stats.on_load) then
	    print(', "on_load": true')
	 else
	    print(', "on_load": false')
	 end
	 
	 if((historical_stats.num_files ~= nil) and (historical_stats.num_files ~= 0))then
	    success_file = historical_stats.num_files - historical_stats.open_error - historical_stats.file_error - historical_stats.query_error
	    file_pctg = math.floor(1+((historical_stats.file_error*100)/historical_stats.num_files))
	    open_pctg = math.floor(1+((historical_stats.open_error*100)/historical_stats.num_files))
	    query_pctg = math.floor(1+((historical_stats.query_error*100)/historical_stats.num_files))
	    success_pctg = math.floor(1+((success_file*100)/historical_stats.num_files))
	    print(', "historical_if_name": "' .. historical_stats.interface_name ..'"') 
	    print(', "historical_tot_files": "' .. historical_stats.num_files ..'"')
	 else
	    success_file = 0
	    file_pctg = 0
	    open_pctg = 0
	    query_pctg = 0
	    success_pctg = 0
	 end
	 
	 print(', "success_file": ' .. success_file.. ', "open_error": ' .. historical_stats.open_error.. ', "file_error": '..historical_stats.file_error ..', "query_error": '..historical_stats.query_error)
	 print(', "success_pctg": ' .. success_pctg..', "open_pctg": ' .. open_pctg.. ', "file_pctg": '.. file_pctg ..', "query_pctg": '..query_pctg)
      else
	 
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
      end

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