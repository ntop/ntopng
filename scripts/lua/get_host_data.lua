--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local json = require "dkjson"
local custom_column_utils = require "custom_column_utils"   
local custom_column = _GET["custom_column"]

sendHTTPHeader('application/json')

function getNetworkStats(network)
   local hosts_stats = interface.getHostsInfo()
   hosts_stats = hosts_stats["hosts"]

   local my_network

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

local host_info = url2hostinfo(_GET)

local criteria = _GET["criteria"]
if(criteria == nil) then criteria = "" end

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

local res = {}

if host then
   local now = os.time()
   -- Get from redis the throughput type bps or pps
   local throughput_type = getThroughputType()

   res["column_since"] = secondsToTime(now-host["seen.first"]+1)
   res["column_last"] = secondsToTime(now-host["seen.last"]+1)
   res["column_traffic"] = bytesToSize(host["bytes.sent"]+host["bytes.rcvd"])

   if not isEmptyString(custom_column) and custom_column_utils.isCustomColumn(custom_column) then
      local custom_column_key, custom_column_format = custom_column_utils.label2criteriakey(custom_column)
      local val = custom_column_utils.hostStatsToColumnValue(host, custom_column_key, true)
      res["column_custom"] = val
   end

   if((host["throughput_trend_"..throughput_type] ~= nil)
   and (host["throughput_trend_"..throughput_type] > 0)) then
      local res_thpt

      if(throughput_type == "pps") then
	 res_thpt = pktsToSize(host["throughput_bps"])
      else
	 res_thpt = bitsToSize(8*host["throughput_bps"])
      end

      -- See ValueTrend in ntop_typedefs.h for values
      if host["throughput_trend_"..throughput_type] == 1 then
	 res_thpt = res_thpt .. " <i class='fas fa-arrow-up'></i>"
      elseif host["throughput_trend_"..throughput_type] == 2 then
	 res_thpt = res_thpt .. " <i class='fas fa-arrow-down'></i>"
      elseif host["throughput_trend_"..throughput_type] == 3 then
	 res_thpt = res_thpt .. " <i class='fas fa-minus'></i>"
      end

      res["column_thpt"] = res_thpt
   else
      res["column_thpt"] = "0 "..throughput_type
   end

   res["column_num_flows"] = host["active_flows.as_client"] + host["active_flows.as_server"]

   if isBridgeInterface(interface.getStats()) then
      res["column_num_dropped_flows"] = (host["flows.dropped"] or 0)
   end

   if((host["num_alerts"] ~= nil) and (host["num_alerts"] > 0)) then
      res["column_alerts"] = host["num_alerts"]
   else
      res["column_alerts"] = 0
   end
   
   sent2rcvd = round((host["bytes.sent"] * 100) / (host["bytes.sent"]+host["bytes.rcvd"]), 0)
   if(sent2rcvd == nil) then sent2rcvd = 0 end
   res["column_breakdown"] = "<div class='progress'><div class='progress-bar bg-warning' style='width: "
	  .. sent2rcvd .."%;'>Sent</div><div class='progress-bar bg-success' style='width: " .. (100-sent2rcvd) .. "%;'>Rcvd</div></div>"

end

print(json.encode(res))
