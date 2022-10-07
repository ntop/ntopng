--
-- (C) 2013-22 - ntop.org
--

local clock_start = os.clock()

require "lua_utils"
local format_utils = require "format_utils"

local network_utils = {}

network_utils.UNKNOWN_NETWORK = 65535 -- uint16 (-1)

-- Get from redis the throughput type bps or pps
local function getThroughputType()
  local throughput_type = ntop.getCache("ntopng.prefs.thpt_content")
  if throughput_type == "" then throughput_type = "bps" end
  
  return throughput_type
end

-- network_utils.throughput_type = getThroughputType()

function network_utils.network2record(ifId, network)
   local record = {}
   local throughput_type = getThroughputType()
   
   record["key"] = tostring(network["network_id"])

   local network_link = "<A HREF='"..ntop.getHttpPrefix()..'/lua/hosts_stats.lua?network='..network["network_id"].."' title='"..network["network_key"].."'>"..getFullLocalNetworkName(network["network_key"])..'</A>'
   
   network["host_score_ratio"] = math.floor(network["score"] / network["num_hosts"])

   record["column_id"] = network_link
   record["column_score"] = format_high_num_value_for_tables(network, "score") 
   record["column_hosts"] = format_high_num_value_for_tables(network, "num_hosts")
   record["column_alerted_flows"] = format_high_num_value_for_tables(network["alerted_flows"], "total")
   record["column_host_score_ratio"] = format_high_num_value_for_tables(network, "host_score_ratio")

   local sent2rcvd = round((network["bytes.sent"] * 100) / (network["bytes.sent"] + network["bytes.rcvd"]), 0)
   record["column_breakdown"] = "<div class='progress'><div class='progress-bar bg-warning' style='width: "
      .. sent2rcvd .."%;'>Sent</div><div class='progress-bar bg-success' style='width: " .. (100-sent2rcvd) .. "%;'>Rcvd</div></div>"

   if(throughput_type == "pps") then
      record["column_thpt"] = pktsToSize(network["throughput_pps"])
   else
      record["column_thpt"] = bitsToSize(8*network["throughput_bps"])
   end

   record["column_traffic"] = bytesToSize(network["bytes.sent"] + network["bytes.rcvd"])

   if not areInterfaceTimeseriesEnabled(ifId) then
      record["column_chart"] = ""
   else
      record["column_chart"] = '<A HREF="'..ntop.getHttpPrefix()..'/lua/network_details.lua?network='..network["network_id"]..'&page=historical"><i class=\'fas fa-chart-area fa-lg\'></i></A>'
   end
   
   return record
end

if(trace_script_duration ~= nil) then
   io.write(debug.getinfo(1,'S').source .." executed in ".. (os.clock()-clock_start)*1000 .. " ms\n")
end

return network_utils
