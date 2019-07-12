--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"
require "flow_utils"
require "historical_utils"
sendHTTPContentTypeHeader('text/html')

interface.select(ifname)
host_info = url2hostinfo(_GET)

-- #####################################################################

function formatPeer(peer)
   return '<A HREF="'..ntop.getHttpPrefix()..'/lua/host_details.lua?host='..peer..'">'..peer..'</A>'
end

-- #####################################################################

local is_host

if(host_info["host"] ~= nil) then
   stats = interface.getHostInfo(host_info["host"], host_info["vlan"])
   is_host = true
else
   stats = interface.getStats()
   is_host = false
end

if(stats ~= nil) then
   local icmp_keys = { "ICMPv4", "ICMPv6" }

   for _, k in pairs(icmp_keys) do
      local icmp = stats[k]
      
      if(icmp ~= nil) then
	 local tot = 0
	 local is_v4

	 if(k == "ICMPv4") then is_v4 = true else is_v4 = false end
	 
	 for key, value in pairsByKeys(icmp) do
	    local keys = string.split(key, ",")
	    local icmp_type = keys[1]
	    local icmp_value = keys[2]
	    print('<tr><td><a href="'..ntop.getHttpPrefix()..'/lua/flows_stats.lua?icmp_type='..
	       icmp_type..'&icmp_cod='..icmp_value..'&version='.. ternary(is_v4, "4", "6") ..'">'..
	       get_icmp_label(icmp_type, icmp_value, is_v4)..'</a>')

	    if(is_host) then
	       print('<td>')
	       if(value.last_host_sent_peer ~= nil) then
		  print(formatPeer(value.last_host_sent_peer))
	       end
	       print('</td>')

	       print('<td>')
	       if(value.last_host_rcvd_peer ~= nil) then
		  print(formatPeer(value.last_host_rcvd_peer))
	       end
	       print('</td>')

	       print('<td>')
	       breakdownBar(value.sent, "Sent", value.rcvd, "Rcvd", 0, 100)
	       print('</td')

	       print('</td><td align=right>'..formatPackets(value.sent).. '</td>')

	       print('</td><td align=right>'..formatPackets(value.rcvd))

	    end
	    
	    print("</td><td align=right>".. (value.sent+value.rcvd) .."</td></tr>\n")
	 end
      end
   end
end
