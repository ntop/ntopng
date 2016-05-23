--
-- (C) 2014-15-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('application/json')

interface.select(ifname)
host_info = url2hostinfo(_GET)
flows     = interface.getFlowPeers(host_info["host"],host_info["vlan"])

tot = 0
peers = {}
peers_proto = {}
ndpi = {}

for key, value in pairs(flows) do
   flow = flows[key]

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

_peers = { }
for key, value in pairs(peers) do
   _peers[value] = key
end

_ndpi = { }
n = 0
for key, value in pairs(ndpi) do
   _ndpi[value] = key
   n = n + 1
end

-- Print up to this number of entries
max_num_peers = 10

print "[\n"
num = 0
for value,peer in pairsByKeys(_peers, rev) do
   if(peers_proto[peer] ~= nil) then
      n = 0
      for value,proto in pairsByKeys(_ndpi, rev) do

	 if(peers_proto[peer][proto] ~= nil) then
	    if((n+num) > 0) then
	       print ",\n"
	    end
      
	    host = interface.getHostInfo(peer)
	    if(host ~= nil) then
  	      if(host["name"] == nil) then
	        host["name"] = ntop.getResolvedAddress(hostinfo2hostkey(host))	
	      end

	      print("\t { \"host\": \"" .. peer .."\", \"name\": \"".. host.name.."\", \"url\": \"<A HREF='"..ntop.getHttpPrefix().."/lua/host_details.lua?host=".. hostinfo2hostkey(host) .."'>"..host.name .."</A>\", \"l7proto\": \"".. proto .."\", \"l7proto_url\": \"<A HREF="..ntop.getHttpPrefix().."/lua/flows_stats.lua?host=".. hostinfo2hostkey(host) .."&application="..proto..">"..proto.."</A>\", \"traffic\": ".. math.log10(peers_proto[peer][proto]) .. " }")
   	      n = n + 1
	    end
	 end
      end

      num = num + 1
      if(num == max_num_peers) then
	 break
      end
   end
end


print "\n]"

