--
-- (C) 2014-15-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")

sendHTTPHeader('application/json')

interface.select(ifname)
local host_info = url2hostinfo(_GET)
local flows     = interface.getFlowPeers(host_info["host"],host_info["vlan"])

local tot = 0
local peers = {}
local peers_proto = {}
local ndpi = {}

for key, flow in pairs(flows) do

   if(flow.client == _GET["host"]) then
      peer = flow.server .. '@' .. flow['server.vlan']
   else
      peer = flow.client .. '@' .. flow['client.vlan']
   end

   v = flow.rcvd + flow.sent
   if(peers[peer] == nil) then peers[peer] = 0  end
   peers[peer] = peers[peer] + v

   if flow["proto.ndpi"] == nil then
      goto continue
   elseif ndpi[flow["proto.ndpi"]] == nil then
      ndpi[flow["proto.ndpi"]] = 0
   end

   ndpi[flow["proto.ndpi"]] = ndpi[flow["proto.ndpi"]] + v

   if(peers_proto[peer] == nil) then peers_proto[peer] = {}  end
   if(peers_proto[peer][flow["proto.ndpi"]] == nil) then peers_proto[peer][flow["proto.ndpi"]] = 0 end
   peers_proto[peer][flow["proto.ndpi"]] = peers_proto[peer][flow["proto.ndpi"]] + v

   ::continue::
   tot = tot + v
end

-- Print up to this number of entries
local max_num_peers = 10
local num = 0

local res = {}

for peer,value in pairsByValues(peers, rev) do
   if(peers_proto[peer] ~= nil) then

      for proto,value in pairsByValues(ndpi, rev) do
	 if(peers_proto[peer][proto] ~= nil) then

	    host = interface.getHostInfo(peer)
	    if(host ~= nil) then
  	      if(host["name"] == nil) then
	        host["name"] = ntop.getResolvedAddress(hostinfo2hostkey(host))	
	      end

	      local r = {host=peer, name=host.name, url="<A HREF='"..ntop.getHttpPrefix().."/lua/host_details.lua?host=".. hostinfo2hostkey(host) .."'>"..host.name .."</A>", l7proto=proto, l7proto_url="<A HREF="..ntop.getHttpPrefix().."/lua/flows_stats.lua?host=".. hostinfo2hostkey(host) .."&application="..proto..">"..proto.."</A>", traffic=math.log10(peers_proto[peer][proto])}

	      res[#res + 1] = r
	    end
	 end
      end

      num = num + 1
      if(num == max_num_peers) then
	 break
      end
   end
end

print(json.encode(res, nil))

