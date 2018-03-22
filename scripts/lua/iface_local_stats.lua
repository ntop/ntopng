--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

ifid = _GET["ifid"]
interface.select(ifid)
ifstats = interface.getStats()

print('[')

if(_GET["iflocalstat_mode"] == "distribution") then
   if(ifstats["localstats"]["bytes"] == 0) then 
      print('{ "label": "No traffic yet", "value": 0 }\n') 
   else
      local ifname = getInterfaceName(ifid)
      local eth = ifstats["eth"]
      local n = 0

      sum = eth.IPv4_packets+eth.IPv6_packets+eth.ARP_packets+eth.MPLS_packets+eth.other_packets
      five = 0.05*sum
      tot = 0
      if(eth.IPv4_packets > five) then print('{ "label": "IPv4", "value": '..eth.IPv4_packets..' }') n = 1 tot = tot + eth.IPv4_packets end      
      if(eth.IPv6_packets > five) then if(n == 1) then print(',') n = 0 end print('{ "label": "IPv6", "value": '..eth.IPv6_packets..' }') n = 1 tot = tot + eth.IPv6_packets end      
      if(eth.ARP_packets > five) then if(n == 1) then print(',') n = 0 end print('{ "label": "ARP", "value": '..eth.ARP_packets..' }') n = 1 tot = tot + eth.ARP_packets end      
      if(eth.MPLS_packets > five) then if(n == 1) then print(',') n = 0 end print('{ "label": "MPLS", "value": '..eth.MPLS_packets..' }') n = 1 tot = tot + eth.MPLS_packets end      
      leftover = sum - tot
      if(leftover > 0) then if(n == 1) then print(',') n = 0 end print('{ "label": "Other", "value": '..leftover..' }') n = 1 end
   end
else 
bytes = ifstats["localstats"]["bytes"]

sum = bytes["local2remote"]+bytes["local2local"]+bytes["remote2local"]+bytes["remote2remote"]
five = 0.05*sum
other = 0

n = 0

if(bytes["local2remote"] > five) then print [[  { "label": "Local->Remote", "value": ]] print(bytes["local2remote"].."") print [[ } ]] n = n + 1 else other = other + bytes["local2remote"] end
if(bytes["local2local"] > five) then if(n > 0) then print(",") end print [[   { "label": "Local->Local", "value": ]] print(bytes["local2local"].."") print [[ } ]]  n = n + 1 else other = other + bytes["local2local"] end
if(bytes["remote2local"] > five) then if(n > 0) then print(",") end print [[   { "label": "Remote->Local", "value": ]] print(bytes["remote2local"].."") print [[ } ]]  n = n + 1 else other = other + bytes["remote2remote"] end
if(bytes["remote2remote"] > five) then if(n > 0) then print(",") end print [[   { "label": "Remote->Remote", "value": ]] print(bytes["remote2remote"].."") print [[ } ]]  n = n + 1 else other = other + bytes["remote2remote"] end

if(other > 0) then  if(n > 0) then print(",") end  print('{ "label": "Other", "value": '..other..' }\n') end

if(sum == 0) then print('{ "label": "No traffic yet", "value": 0 }\n') end
end

print(']')
