--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local discover = require "discover_utils"
local json = require "dkjson"

sendHTTPContentTypeHeader('text/html')

local hosts = interface.getLocalHostsInfo(true, "column_traffic")

function isanomaly(value)
   if(value > 0) then
      if((value < 25) or (value > 75)) then
	 return true
      end
   end

   return false
end

for k,h in pairs(hosts.hosts) do
   -- TODO: add counter for discarding mostly idle hosts
   print("<A HREF='/lua/host_details.lua?host="..k.."' target=_blank>"..k.."</A> ")

   if(h["active_flows.as_client.anomaly_index"] ~= nil) then
      if(isanomaly(h["active_flows.as_client.anomaly_index"]) == true) then
	 print("[active_flows.as_client.anomaly_index: "..h["active_flows.as_client.anomaly_index"].."]")
      end
   end

   if(h["active_flows.as_server.anomaly_index"] ~= nil) then
      if(isanomaly(h["active_flows.as_server.anomaly_index"]) == true) then
	 print("[active_flows.as_server.anomaly_index: "..h["active_flows.as_server.anomaly_index"].."]")
      end
   end

   if(h["tcp.bytes.sent.anomaly_index"] ~= nil) then
      if(isanomaly(h["tcp.bytes.sent.anomaly_index"]) == true) then print("[tcp.bytes.sent: "..h["tcp.bytes.sent.anomaly_index"].."]") end
      if(isanomaly(h["tcp.bytes.rcvd.anomaly_index"]) == true) then print("[tcp.bytes.rcvd: "..h["tcp.bytes.rcvd.anomaly_index"].."]") end
      if(isanomaly(h["udp.bytes.sent.anomaly_index"]) == true) then print("[udp.bytes.sent: "..h["udp.bytes.sent.anomaly_index"].."]") end
      if(isanomaly(h["udp.bytes.rcvd.anomaly_index"]) == true) then print("[udp.bytes.rcvd: "..h["udp.bytes.rcvd.anomaly_index"].."]") end
      if(isanomaly(h["icmp.bytes.sent.anomaly_index"]) == true) then print("[icmp.bytes.sent: "..h["icmp.bytes.sent.anomaly_index"].."]") end
      if(isanomaly(h["icmp.bytes.rcvd.anomaly_index"]) == true) then print("[icmp.bytes.rcvd: "..h["icmp.bytes.rcvd.anomaly_index"].."]") end
      if(isanomaly(h["other_ip.bytes.sent.anomaly_index"]) == true) then print("[other_ip.bytes.sent: "..h["other_ip.bytes.sent.anomaly_index"].."]") end
      if(isanomaly(h["other_ip.bytes.rcvd.anomaly_index"]) == true) then print("[other_ip.bytes.rcvd: "..h["other_ip.bytes.rcvd.anomaly_index"].."]") end
   end

   print("<br>\n")
end
