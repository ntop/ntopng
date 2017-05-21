require "lua_utils"

-- Get from redis the throughput type bps or pps
local throughput_type = getThroughputType()

local now = os.time()

function as2record(as)
   local record = {}
   record["key"] = tostring(as["asn"])

   local as_link = "<A HREF='"..ntop.getHttpPrefix()..'/lua/hosts_stats.lua?asn='..as["asn"].."' title='"..as["asname"].."'>"..as["asn"]..'</A>'
   record["column_asn"] = as_link

   record["column_asname"] = printASN(as["asn"], as["asname"])

   record["column_hosts"] = as["num_hosts"]..""
   record["column_since"] = secondsToTime(now - as["seen.first"] + 1)

   local sent2rcvd = round((as["bytes.sent"] * 100) / (as["bytes.sent"] + as["bytes.rcvd"]), 0)
   record["column_breakdown"] = "<div class='progress'><div class='progress-bar progress-bar-warning' style='width: "
      .. sent2rcvd .."%;'>Sent</div><div class='progress-bar progress-bar-info' style='width: " .. (100-sent2rcvd) .. "%;'>Rcvd</div></div>"

   if(throughput_type == "pps") then
      record["column_thpt"] = pktsToSize(as["throughput_pps"])
   else
      record["column_thpt"] = bitsToSize(8*as["throughput_bps"])
   end

   record["column_traffic"] = bytesToSize(as["bytes.sent"] + as["bytes.rcvd"])

   record["column_chart"] = ""
   local asnstats_rrd = fixPath(dirs.workingdir .. "/" ..getInterfaceId(ifname)..'/asnstats/'..as["asn"]..'/bytes.rrd')
   if ntop.exists(asnstats_rrd) then
      record["column_chart"] = '<A HREF="'..ntop.getHttpPrefix()..'/lua/hosts_stats.lua?asn='..as["asn"]..'&page=historical"><i class=\'fa fa-area-chart fa-lg\'></i></A>'
   end

   return record
end

