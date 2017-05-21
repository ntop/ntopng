--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"
require "historical_utils"
sendHTTPContentTypeHeader('text/html')

interface.select(ifname)
host_info = url2hostinfo(_GET)

-- #####################################################################

local icmp_v4_msgs = {
   { 0, 0, "Echo Reply" },
   { 3, 0, "Destination Network Unreachable" },
   { 3, 1, "Destination Host Unreachable" },
   { 3, 2, "Destination Protocol Unreachable]" },
   { 3, 3, "Destination Port Unreachable" },
   { 3, 4, "Fragmentation required, and DF flag set" },
   { 3, 6, "Destination Network Unknown" },
   { 3, 7, "Destination Host Unknown" },
   { 3, 0, "Destination Unreachable" },   
   { 4, 0, "Source Quench" },
   { 5, 0, "Redirect" },
   { 8, 0, "Echo Request" },
   { 9, 0,  "Router Advertisement" },
   { 10, 0, "Router Selection" },
   { 11, 0, "Time Exceeded: TTL expired in transit" },
   { 11, 1, "Time Exceeded: Fragment reassembly time exceeded" },
   { 12, 0, "Parameter Problem" },
   { 13, 0, "Timestamp Request" },
   { 14, 0, "Timestamp Reply" },
   { 15, 0, "Information Request" },
   { 16, 0, "Information Reply" },
   { 17, 0, "Address Mask Request" },
   { 18, 0, "Address Mask Reply" },
   { 30, 0, "Traceroute" },
}

local icmp_v6_msgs = {
   { 1, 0,  "Destination Unreachable" },
   { 2, 0,  "Packet Too Big" },
   { 3, 0, "Time Exceeded: hop limit exceeded in transit" },
   { 3, 1, "Time Exceeded: fragment reassembly time exceeded" },
   { 4, 0, "Parameter Problem" },
   { 128, 0, "Echo Request" },
   { 129, 0, "Echo Reply" },
   { 133, 0, "Router Solicitation" },
   { 134, 0, "Router Advertisement" },
   { 135, 0, "Neighbor Solicitation" },
   { 136, 0, "Neighbor Advertisement" },
}

function get_icmp_label(icmp_type, icmp_value, is_v4, is_host)
   local what, label

   if(is_v4) then
      what = icmp_v4_msgs
      label = "ICMPv4"
   else
      what = icmp_v6_msgs
      label = "ICMPv6"
   end
   
   for _, k in pairs(what) do
      local i_type  = tostring(k[1])
      local i_value = tostring(k[2])
      local i_msg   = k[3]

      -- print(i_type.."/"..icmp_type.."<br>\n")
      if(i_type == icmp_type) then
	 -- print("))"..i_type.."/"..icmp_type.."<br>\n")
	 if(i_value == icmp_value) then
	    return(i_msg)
	 end
      end
   end
   
   return(label.." [type: "..icmp_type.."][value: "..icmp_value.."]")
end

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
	 
	 for key, value in pairs(icmp) do
	    local keys = string.split(key, ",")
	    local icmp_type = keys[1]
	    local icmp_value = keys[2]
	    print('<tr><td>'..get_icmp_label(icmp_type, icmp_value, is_v4, is_host))

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
	    
	    print("</td><td align=right>".. formatPackets(value.sent+value.rcvd) .."</td></tr>\n")
	 end
      end
   end
end
