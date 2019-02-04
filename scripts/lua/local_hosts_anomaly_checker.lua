--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local discover = require "discover_utils"
local json = require "dkjson"

sendHTTPContentTypeHeader('text/html')

local hosts = interface.getLocalHostsInfo(true, "column_traffic")


for k,h in pairs(hosts.hosts) do
   tprint(h)
   
   print(k.." ")
   
   if(h["active_flows.as_client.anomaly_index"] ~= nil) then
      if(h["active_flows.as_client.anomaly_index"] > 0) then
	 print("[client: "..h["active_flows.as_client.anomaly_index"].."]")
      end
   end
   
   if(h["active_flows.as_client.anomaly_index"] ~= nil) then
      if(h["active_flows.as_client.anomaly_index"] > 0) then
	 print("[client: "..h["active_flows.as_client.anomaly_index"].."]")
      end
   end

   if(h["tcp.bytes.sent.anomaly_index"] > 0) then
      if(h["tcp.bytes.sent.anomaly_index"] > 0) then print("[tcp.bytes.sent: "..h["tcp.bytes.sent.anomaly_index"].."]") end
      if(h["tcp.bytes.rcvd.anomaly_index"] > 0) then print("[tcp.bytes.rcvd: "..h["tcp.bytes.rcvd.anomaly_index"].."]") end
      if(h["udp.bytes.sent.anomaly_index"] > 0) then print("[udp.bytes.sent: "..h["udp.bytes.sent.anomaly_index"].."]") end
      if(h["udp.bytes.rcvd.anomaly_index"] > 0) then print("[udp.bytes.rcvd: "..h["udp.bytes.rcvd.anomaly_index"].."]") end
      if(h["icmp.bytes.sent.anomaly_index"] > 0) then print("[icmp.bytes.sent: "..h["icmp.bytes.sent.anomaly_index"].."]") end
      if(h["icmp.bytes.rcvd.anomaly_index"] > 0) then print("[icmp.bytes.rcvd: "..h["icmp.bytes.rcvd.anomaly_index"].."]") end
      if(h["other_ip.bytes.sent.anomaly_index"] > 0) then print("[other_ip.bytes.sent: "..h["other_ip.bytes.sent.anomaly_index"].."]") end
      if(h["other_ip.bytes.rcvd.anomaly_index"] > 0) then print("[other_ip.bytes.rcvd: "..h["other_ip.bytes.rcvd.anomaly_index"].."]") end
   end
   
   print("<br>\n")
end
