--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"

sendHTTPContentTypeHeader('text/html')
local debug = debug_flow_data


local flow_key = _GET["flow_key"]
local flow_hash_id = _GET["flow_hash_id"]
local flow = interface.findFlowByKeyAndHashId(tonumber(flow_key), tonumber(flow_hash_id))

local throughput_type = getThroughputType()

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
       print("<i class='fas fa-arrow-up'></i>")
       elseif(flow["throughput_trend_"..throughput_type] == 2) then
       print("<i class='fas fa-arrow-down'></i>")
       elseif(flow["throughput_trend_"..throughput_type] == 3) then
       print("<i class='fas fa-minus'></i>")
    end

      print("\"")
   else
      print ("\", \"column_thpt\" : \"0 "..throughput_type.." \"")
   end

   if isScoreEnabled() then
      print(", \"column_score\" : \""..formatValue(flow["score"]).."\"")
   end

   cli2srv = round((flow["cli2srv.bytes"] * 100) / flow["bytes"], 0)
   print (", \"column_breakdown\" : \"<div class='progress'><div class='progress-bar bg-warning' style='width: " .. cli2srv .."%;'>Client</div><div class='progress-bar bg-info' style='width: " .. (100-cli2srv) .. "%;'>Server</div></div>")

   print ("\" }")

end
