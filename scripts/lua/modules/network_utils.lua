--
-- (C) 2013-22 - ntop.org
--

require "lua_utils"
local format_utils = require "format_utils"

-- Get from redis the throughput type bps or pps
local throughput_type = getThroughputType()

function network2record(ifId, network)
   local record = {}
   record["key"] = tostring(network["network_id"])

   local network_link = "<A HREF='"..ntop.getHttpPrefix()..'/lua/hosts_stats.lua?network='..network["network_id"].."' title='"..network["network_key"].."'>"..getFullLocalNetworkName(network["network_key"])..'</A>'
   record["column_id"] = network_link
   record["column_score"] = format_utils.formatValue(network["score"] or 0)
   record["column_hosts"] = (network["num_hosts"] or 0)..""

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

