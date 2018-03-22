--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"


sendHTTPContentTypeHeader('text/html')
local debug = debug_flow_data


flow_key = _GET["flow_key"]
if(flow_key == nil) then
   flow = nil
else
   interface.select(ifname)
   flow = interface.findFlowByKey(tonumber(flow_key))
end

throughput_type = getThroughputType()

if(flow == nil) then
   print('{}')
else
  print ("{ \"column_duration\" : \"" .. secondsToTime(flow["duration"]))
  print ("\", \"column_bytes\" : \"" .. bytesToSize(flow["bytes"]) .. "")

 if ( (flow["throughput_trend_"..throughput_type] ~= nil) and 
      (flow["throughput_trend_"..throughput_type] > 0) 
  ) then

    if (throughput_type == "pps") then
      print ("\", \"column_thpt\" : \"" .. pktsToSize(flow["throughput_pps"]).. " ")
    else
      print ("\", \"column_thpt\" : \"" .. bitsToSize(8*flow["throughput_bps"]).. " ")
    end

    if(flow["throughput_trend_"..throughput_type] == 1) then 
       print("<i class='fa fa-arrow-up'></i>")
       elseif(flow["throughput_trend_"..throughput_type] == 2) then
       print("<i class='fa fa-arrow-down'></i>")
       elseif(flow["throughput_trend_"..throughput_type] == 3) then
       print("<i class='fa fa-minus'></i>")
    end

      print("\"")
   else
      print ("\", \"column_thpt\" : \"0 "..throughput_type.." \"")
   end

   cli2srv = round((flow["cli2srv.bytes"] * 100) / flow["bytes"], 0)
   print (", \"column_breakdown\" : \"<div class='progress'><div class='progress-bar progress-bar-warning' style='width: " .. cli2srv .."%;'>Client</div><div class='progress-bar progress-bar-info' style='width: " .. (100-cli2srv) .. "%;'>Server</div></div>")

   print ("\" }")

end
