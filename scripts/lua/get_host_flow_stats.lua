--
-- (C) 2013-20 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local json = require("dkjson")

require "lua_utils"

-- Do not use sendHTTPHeader('application/json') as the pie chart expects text/html
sendHTTPContentTypeHeader('text/html')

interface.select(ifname)

host_info = url2hostinfo(_GET)
host = interface.getHostInfo(host_info["host"],host_info["vlan"])
mode = _GET["mode"]

-- tprint(host.bins)

postfix = ""

if(host == nil) then
   bins = {}
else
   if(mode == "client_duration") then
      bins = host.bins.client.duration
      postfix = " sec"
   elseif(mode == "server_duration") then
      bins = host.bins.server.duration
      postfix = " sec"
      -- print((host["flows.as_server"]-host["active_flows.as_server"]).."\n")
   elseif(mode == "client_frequency") then
      bins = host.bins.client.frequency
      postfix = " sec"
   elseif(mode == "server_frequency") then
      bins = host.bins.server.frequency
      postfix = " sec"
   end
end

-- tprint(bins)

num = 0
rsp = "["

total = 0

for k,v in pairs(bins) do
   k = k .. postfix
   v = truncate(v*100)

   if(v > 2) then
      if(num > 0) then rsp = rsp .. "," end
      rsp = rsp .. '\n\t{ "label": "'..k..'", "value": '.. v .. '}'
      num = num + 1
      total = total + v
   end
end

if(total < 100) then
   if(num > 0) then rsp = rsp .. "," end
   rsp = rsp .. '\n\t{ "label": "Other", "value": '.. (100-total) .. '}'
end

rsp = rsp .. "\n]"

print(rsp)
