--
-- (C) 2014-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

-- ########################################################

local os_data_utils = {}

-- ########################################################

local now = os.time()

function os_data_utils.os2record(ifId, os)
   local discover = require("discover_utils")

   -- Get from redis the throughput type bps or pps
   local throughput_type = getThroughputType()
   local record = {}
   record["key"] = tostring(os["os"])

   if os["os"] ~= nil then
      record["column_id"] = " <A HREF='"..ntop.getHttpPrefix().."/lua/hosts_stats.lua?os=".. os["os"] .."'>" 
      record["column_id"] = record["column_id"] .. discover.getOsAndIcon(os["os"]) .."</A>"
   end

   if((os["num_alerts"] ~= nil) and (os["num_alerts"] > 0)) then
      record["column_alerts"] = "<font color=#B94A48>"..formatValue(value["num_alerts"]).."</font>"
   else
      record["column_alerts"] = ""
   end

   record["column_chart"] = ""

   if areOSTimeseriesEnabled(ifId) then
      record["column_chart"] = '<A HREF="'..ntop.getHttpPrefix()..'/lua/os_details.lua?os='..os["os"]..'&page=historical"><i class=\'fas fa-chart-area fa-lg\'></i></A>'
   end

   record["column_hosts"] = format_high_num_value_for_tables(os, "num_hosts")
   record["column_since"] = secondsToTime(now - os["seen.first"] + 1)
   
   local sent2rcvd = round((os["bytes.sent"] * 100) / (os["bytes.sent"] + os["bytes.rcvd"]), 0)
   record["column_breakdown"] = "<div class='progress'><div class='progress-bar bg-warning' style='width: "
      .. sent2rcvd .."%;'>Sent</div><div class='progress-bar bg-success' style='width: " .. (100-sent2rcvd) .. "%;'>Rcvd</div></div>"

   if(throughput_type == "pps") then
      record["column_thpt"] = pktsToSize(os["throughput_pps"])
   else
      record["column_thpt"] = bitsToSize(8*os["throughput_bps"])
   end

   record["column_traffic"] = bytesToSize(os["bytes.sent"] + os["bytes.rcvd"])

   return record
end

-- ########################################################

return os_data_utils

