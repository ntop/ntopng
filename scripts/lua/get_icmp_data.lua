--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local graph_utils = require "graph_utils"
require "flow_utils"
require "historical_utils"
local icmp_utils = require "icmp_utils"

sendHTTPContentTypeHeader('text/html')

interface.select(ifname)
local host_info = url2hostinfo(_GET)
local ip_version = _GET["version"]

-- #####################################################################

function formatPeer(peer)
   return ip2detailshref(peer, nil, peer)
end

-- #####################################################################

local is_host
local stats

if(host_info["host"] ~= nil) then
   stats = interface.getHostInfo(host_info["host"], host_info["vlan"])
   is_host = true
else
   stats = interface.getStats()
   is_host = false
end

if(stats ~= nil) then
   local icmp_keys = {}

   if not ip_version or ip_version == "4" then
      icmp_keys[#icmp_keys + 1] = "ICMPv4"
   end

   if not ip_version or ip_version == "6" then
      icmp_keys[#icmp_keys + 1] = "ICMPv6"
   end

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
		     icmp_utils.get_icmp_label(ternary(is_v4, 4, 6), icmp_type, icmp_value)..'</a>')

	    print(string.format("<td>%u</td>", icmp_type))
	    print(string.format("<td>%u</td>", icmp_value))

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
	       graph_utils.breakdownBar(value.sent, "Sent", value.rcvd, "Rcvd", 0, 100)
	       print('</td')

	       print('</td><td align=right>'..formatPackets(value.sent).. '</td>')

	       print('</td><td align=right>'..formatPackets(value.rcvd))

	    end

	    print("</td><td align=right>".. formatPackets(value.sent + value.rcvd) .."</td></tr>\n")
	 end
      end
   end
end
