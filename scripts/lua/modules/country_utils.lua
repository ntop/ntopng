require "lua_utils"

-- Get from redis the throughput type bps or pps
local throughput_type = getThroughputType()

local now = os.time()

function country2record(ifId, country)
   local record = {}
   record["key"] = tostring(country["country"])

   local country_link = "<A HREF='"..ntop.getHttpPrefix()..'/lua/hosts_stats.lua?country='..country["country"].."' title='"..country["country"].."'>"..country["country"]..'</A>'
   record["column_id"] = getFlag(country["country"]).."&nbsp&nbsp" .. country_link

   record["column_hosts"] = country["num_hosts"]..""
   record["column_score"] = country["score"]
   record["column_since"] = secondsToTime(now - country["seen.first"] + 1)

   local sent2rcvd = round((country["egress"] * 100) / (country["egress"] + country["ingress"]), 0)
   record["column_breakdown"] = "<div class='progress'><div class='progress-bar bg-warning' style='width: "
      .. sent2rcvd .."%;'>Sent</div><div class='progress-bar bg-success' style='width: " .. (100-sent2rcvd) .. "%;'>Rcvd</div></div>"

   if(throughput_type == "pps") then
      record["column_thpt"] = pktsToSize(country["throughput_pps"])
   else
      record["column_thpt"] = bitsToSize(8*country["throughput_bps"])
   end

   record["column_traffic"] = bytesToSize(country["bytes"])

   record["column_chart"] = ""

   if areCountryTimeseriesEnabled(ifId) then
      record["column_chart"] = '<A HREF="'..ntop.getHttpPrefix()..'/lua/country_details.lua?country='..country["country"]..'&page=historical"><i class=\'fas fa-chart-area fa-lg\'></i></A>'
   end

   return record
end

