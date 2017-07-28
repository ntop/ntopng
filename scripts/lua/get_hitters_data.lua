--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')
local debug = false
local debug_process = false -- Show flow processed information

interface.select(ifname)
ifstats = interface.getStats()
-- printGETParameters(_GET)


-- Table parameters
all = _GET["all"]
perPage     = _GET["perPage"]
sortColumn  = _GET["sortColumn"]
sortOrder   = _GET["sortOrder"]
host_info   = url2hostinfo(_GET)
port        = _GET["port"]
application = _GET["application"]
network_id  = _GET["network"]
vhost       = _GET["vhost"]

-- System host parameters
hosts  = _GET["hosts"]
user   = _GET["username"]
host   = _GET["host"]
pid    = tonumber(_GET["pid"])
name   = _GET["pid_name"]

interface.select(ifname)
flows_stats = interface.getFlowsInfo(host)
flows_stats = flows_stats["flows"]

vals = {}
hitters = {}

for key, value in ipairs(flows_stats) do
   if(flows_stats[key]["cli.ip"] == host) then
      peer = flows_stats[key]["srv.ip"]
      if(hitters[peer] == nil) then
	 hitters[peer] = interface.getPeerHitRate(flows_stats[key]["srv.key"], host)
      end
   else
      peer = flows_stats[key]["cli.ip"]
      if(hitters[peer] == nil) then
	 hitters[peer] = interface.getPeerHitRate(flows_stats[key]["cli.key"], host)
      end
   end   
end


print("{ ")

sent_to_hitters   = {}
rcvd_from_hitters = {}
extra = 0.01 -- Used to avoid overwriting values with the same number of bytes
for k,v in pairs(hitters) do
   if(v["sent"] > 0) then
      sent_to_hitters[v["sent"]+extra] = k 
   end

   if(v["rcvd"] > 0) then
      rcvd_from_hitters[v["rcvd"]+extra] = k 
   end

   extra = extra + 0.01
end

print(' "top_destinations": [ ')

local num = 0
for _value,_key in pairsByKeys(sent_to_hitters, rev) do   
   peer_name = getResolvedAddress(hostkey2hostinfo(_key))
   h="<A HREF='"..ntop.getHttpPrefix().."/lua/host_details.lua?host=" .. _key.. "'>".. shortenString(peer_name).."</A>"
   
   if(num > 0) then print(",") end
   print(' { "ip": "'.._key..'", "host": "'..h..'", "bytes": '..round(_value, 0)..' }')

   num = num + 1
   if(num == 10) then break end
end

-- ######################################

print('], "top_senders": [ ')

num = 0
for _value,_key in pairsByKeys(rcvd_from_hitters, rev) do
   peer_name = getResolvedAddress(hostkey2hostinfo(_key))
   h="<A HREF='"..ntop.getHttpPrefix().."/lua/host_details.lua?host=" .. _key.. "'>".. shortenString(peer_name).."</A>"
   
   if(num > 0) then print(",") end
   print(' { "ip": "'.._key..'", "host": "'..h..'", "bytes": '..round(_value, 0)..' }')

   num = num + 1
   if(num == 10) then break end
end

print('] }')
