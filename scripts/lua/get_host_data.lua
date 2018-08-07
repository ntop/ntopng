--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPContentTypeHeader('text/html')


function getNetworkStats(network)
   local hosts_stats = interface.getHostsInfo()
   hosts_stats = hosts_stats["hosts"]

   my_network = nil

   for key, value in pairs(hosts_stats) do
      h = hosts_stats[key]
      nw_name = h["local_network_name"]

      if(h["local_network_name"] == network) then
	 --io.write(nw_name.."\n")

	 if(nw_name ~= nil) then
	    if(my_network == nil) then
	       h["ip"] = nw_name
	       h["name"] = nw_name
	       my_network = h
	    else
	       my_network["num_alerts"] = my_network["num_alerts"] + h["num_alerts"]
	       my_network["throughput_bps"] = my_network["throughput_bps"] + h["throughput_bps"]
	       my_network["throughput_pps"] = my_network["throughput_pps"] + h["throughput_pps"]
	       my_network["last_throughput_bps"] = my_network["last_throughput_bps"] + h["last_throughput_bps"]
	       my_network["last_throughput_pps"] = my_network["last_throughput_pps"] + h["last_throughput_pps"]
	       my_network["bytes.sent"] = my_network["bytes.sent"] + h["bytes.sent"]
	       my_network["bytes.rcvd"] = my_network["bytes.rcvd"] + h["bytes.rcvd"]

	       if(my_network["seen.first"] > h["seen.first"]) then
		  my_network["seen.first"] = h["seen.first"]
	       end

	       if(my_network["seen.last"] < h["seen.last"]) then
		  my_network["seen.last"] = h["seen.last"]
	       end
	    end
	 end
      end
   end

   return(my_network)
end


-- sendHTTPHeader('application/json')
interface.select(ifname)

host_info = url2hostinfo(_GET)

criteria = _GET["criteria"]
if(criteria == nil) then criteria = "" end

interface.select(ifname)

if(host_info["host"] ~= nil) then
   if(string.contains(host_info["host"], "/")) then
      -- This is a network
      host = getNetworkStats(host_info["host"])
   else
      host = interface.getHostInfo(host_info["host"], host_info["vlan"])
   end
else
   host = interface.getAggregatedHostInfo(host_info["host"])
end


if(host == nil) then
   print('{}')
else
   print('{')
   now = os.time()
   -- Get from redis the throughput type bps or pps
   throughput_type = getThroughputType()

   --tprint(host)

   print("\"column_since\" : \"" .. secondsToTime(now-host["seen.first"]+1) .. "\", ")
   print("\"column_last\" : \"" .. secondsToTime(now-host["seen.last"]+1) .. "\", ")
   print("\"column_traffic\" : \"" .. bytesToSize(host["bytes.sent"]+host["bytes.rcvd"]).. "\", ")

   label, fnctn = label2criteriakey(criteria)

   c = host.criteria
   if(c ~= nil) then print("\"column_"..criteria.."\" : \"" .. fnctn(c[label]).. "\", ") end
   
   if((host["throughput_trend_"..throughput_type] ~= nil)
   and (host["throughput_trend_"..throughput_type] > 0)) then
      if(throughput_type == "pps") then
	 print ("\"column_thpt\" : \"" .. pktsToSize(host["throughput_bps"]).. " ")
      else
	 print ("\"column_thpt\" : \"" .. bitsToSize(8*host["throughput_bps"]).. " ")
      end
      
      if(host["throughput_"..throughput_type] > host["last_throughput_"..throughput_type]) then
	 print("<i class='fa fa-arrow-up'></i>")
	 elseif(host["throughput_"..throughput_type] < host["last_throughput_"..throughput_type]) then
	 print("<i class='fa fa-arrow-down'></i>")
      else
	 print("<i class='fa fa-minus'></i>")
      end
      print("\",")
   else
      print ("\"column_thpt\" : \"0 "..throughput_type.."\",")
   end

   print ("\"column_num_flows\" : \""..host["active_flows.as_client"]+host["active_flows.as_server"].."\",")

   if isBridgeInterface(interface.getStats()) then
      print ("\"column_num_dropped_flows\" : \""..(host["flows.dropped"] or 0).."\",")
   end

   print ("\"column_alerts\" : \"")
   if((host["num_alerts"] ~= nil) and (host["num_alerts"] > 0)) then
      print(""..host["num_alerts"].."\",")
   else
      print("0\",")
   end
   
   sent2rcvd = round((host["bytes.sent"] * 100) / (host["bytes.sent"]+host["bytes.rcvd"]), 0)
   if(sent2rcvd == nil) then sent2rcvd = 0 end
   print ("\"column_breakdown\" : \"<div class='progress'><div class='progress-bar progress-bar-warning' style='width: "
	  .. sent2rcvd .."%;'>Sent</div><div class='progress-bar progress-bar-info' style='width: " .. (100-sent2rcvd) .. "%;'>Rcvd</div></div>")

   
   print("\" } ")

end
