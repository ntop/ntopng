--
-- (C) 2013-23 - ntop.org
--

require "lua_utils"
local format_utils = require "format_utils"

-- Get from redis the throughput type bps or pps
local throughput_type = getThroughputType()

local now = os.time()

function as2record(ifId, as)
   local record = {}
   record["key"] = tostring(as["asn"])

   local as_link = "<A HREF='"..ntop.getHttpPrefix()..'/lua/hosts_stats.lua?asn='..as["asn"].."' title='"..as["asname"].."'>"..as["asn"]..'</A>'
   as["host_score_ratio"] = math.floor(as["score"] / as["num_hosts"])
   
   record["column_asn"] = as_link
   record["column_asname"] = printASN(as["asn"], as["asname"])
   record["column_score"] = format_high_num_value_for_tables(as, "score") 
   record["column_hosts"] = format_high_num_value_for_tables(as, "num_hosts")
   record["column_since"] = secondsToTime(now - as["seen.first"] + 1)
   record["column_host_score_ratio"] = format_high_num_value_for_tables(as, "host_score_ratio")

   local sent2rcvd = round((as["bytes.sent"] * 100) / (as["bytes.sent"] + as["bytes.rcvd"]), 0)
   record["column_breakdown"] = "<div class='progress'><div class='progress-bar bg-warning' style='width: "
      .. sent2rcvd .."%;'>Sent</div><div class='progress-bar bg-success' style='width: " .. (100-sent2rcvd) .. "%;'>Rcvd</div></div>"

   if(throughput_type == "pps") then
      record["column_thpt"] = pktsToSize(as["throughput_pps"])
   else
      record["column_thpt"] = bitsToSize(8*as["throughput_bps"])
   end

   record["column_traffic"] = bytesToSize(as["bytes.sent"] + as["bytes.rcvd"])

   record["column_chart"] = ""

   if areASTimeseriesEnabled(ifId) then
      record["column_chart"] = '<A HREF="'..ntop.getHttpPrefix()..'/lua/as_details.lua?asn='..as["asn"]..'&page=historical"><i class=\'fas fa-chart-area fa-lg\'></i></A>'
   end

   record["column_alerted_flows"] = format_utils.formatValue(as["alerted_flows"]["total"] or 0)
   if record["column_alerted_flows"] == '0' then
    record["column_alerted_flows"] = ''
   end

   return record
end

