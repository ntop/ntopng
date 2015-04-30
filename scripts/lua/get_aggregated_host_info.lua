--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "graph_utils"

hostname = _GET["name"]

interface.select(ifname)
host = interface.getAggregatedHostInfo(hostname)

sendHTTPHeader('text/html; charset=iso-8859-1')
--sendHTTPHeader('application/json')

if(host == nil) then
   print('{ "name": \"' .. hostname .. '\"}\n')
   return
else
   diff = os.time()-host["seen.last"]
   print('{ "name": \"' .. hostname .. '\", "last_seen": "' .. formatEpoch(host["seen.last"]) .. ' ['.. secondsToTime(diff) .. ' ago]", "num_queries": ' .. host["queries.rcvd"] .. 
   ', "traffic_volume": "' .. bytesToSize(host["bytes.sent"]+host["bytes.rcvd"]) .. '", "epoch": ' .. os.time())

print(', "contacts": [')

num = 0
for k,v in pairs(host["contacts"]["client"]) do 
   if(num > 0) then print(",") end
   print('{ "key": "'..k..'", "value": '..v..'}')
   num = num + 1 
end

print ('] }\n')

end