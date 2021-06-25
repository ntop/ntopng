require "lua_utils"
local format_utils = require "format_utils"
local os_utils = require "os_utils"

-- Get from redis the throughput type bps or pps
local throughput_type = getThroughputType()

local now = os.time()

function vlan2record(ifId, vlan)
   local record = {}
   record["key"] = tostring(vlan["vlan_id"])

   local vlan_link = "<A HREF='"..ntop.getHttpPrefix()..'/lua/hosts_stats.lua?vlan='..vlan["vlan_id"].."' title='VLAN "..vlan["vlan_id"].."'>"..getFullVlanName(vlan["vlan_id"])..'</A>'
   record["column_vlan"] = vlan_link

   record["column_score"] = vlan["score"] > 0 and format_utils.formatValue(vlan["score"]) or ''
   record["column_hosts"] = format_utils.formatValue(vlan["num_hosts"])
   record["column_since"] = secondsToTime(now - vlan["seen.first"] + 1)

   local sent2rcvd = round((vlan["bytes.sent"] * 100) / (vlan["bytes.sent"] + vlan["bytes.rcvd"]), 0)
   record["column_breakdown"] = "<div class='progress'><div class='progress-bar bg-warning' style='width: "
      .. sent2rcvd .."%;'>Sent</div><div class='progress-bar bg-success' style='width: " .. (100-sent2rcvd) .. "%;'>Rcvd</div></div>"

   if(throughput_type == "pps") then
      record["column_thpt"] = pktsToSize(vlan["throughput_pps"])
   else
      record["column_thpt"] = bitsToSize(8*vlan["throughput_bps"])
   end

   record["column_traffic"] = bytesToSize(vlan["bytes.sent"] + vlan["bytes.rcvd"])

   record["column_chart"] = ""

   if areVlanTimeseriesEnabled(ifId) then
      record["column_chart"] = '<A HREF="'..ntop.getHttpPrefix()..'/lua/vlan_details.lua?vlan='..vlan["vlan_id"]..'&page=historical"><i class=\'fas fa-chart-area fa-lg\'></i></A>'
   end

   return record
end

