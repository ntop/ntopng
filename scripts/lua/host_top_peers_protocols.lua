--
-- (C) 2014-15-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")

sendHTTPHeader('application/json')

interface.select(ifname)
local max_num_peers = 10
local host_info = url2hostinfo(_GET)
local flows     = getTopFlowPeers(hostinfo2hostkey(host_info), max_num_peers)

local tot = 0
local peers = {}
local peers_proto = {}
local ndpi = {}

for _, flow in ipairs(flows) do

   if(flow["cli.ip"] == _GET["host"]) then
      peer = hostinfo2hostkey(flow, "srv")
   else
      peer = hostinfo2hostkey(flow, "cli")
   end

   v = flow["bytes"]
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

local res = {}

for peer,value in pairsByValues(peers, rev) do
   if(peers_proto[peer] ~= nil) then

      for proto,value in pairsByValues(ndpi, rev) do
	 if(peers_proto[peer][proto] ~= nil) then

	    host = interface.getHostInfo(peer)
	    if(host ~= nil) then
  	      if(host["name"] == nil) then
	        host["name"] = getResolvedAddress(host)
	      end

	      local r = {host=peer, name=host.name, url="<A HREF='"..ntop.getHttpPrefix().."/lua/host_details.lua?host=".. hostinfo2hostkey(host) .."'>"..host.name .."</A>", l7proto=proto, l7proto_url="<A HREF='"..ntop.getHttpPrefix().."/lua/flows_stats.lua?host=".. hostinfo2hostkey(host) .."&application="..proto.."'>"..proto.."</A>", traffic=math.log10(peers_proto[peer][proto])}

	      res[#res + 1] = r
	    end
	 end
      end
   end
end
-- tprint(res)
print(json.encode(res, nil))

