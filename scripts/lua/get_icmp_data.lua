--
-- (C) 2013-18 - ntop.org
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
   { 0, 0, i18n("icmp_v4_msgs.type_0_0_echo_reply") },
   { 3, 0, i18n("icmp_v4_msgs.type_3_0_destination_network_unreachable") },
   { 3, 1, i18n("icmp_v4_msgs.type_3_1_destination_host_unreachable") },
   { 3, 2, i18n("icmp_v4_msgs.type_3_2_destination_protocol_unreachable") },
   { 3, 3, i18n("icmp_v4_msgs.type_3_3_destination_port_unreachable") },
   { 3, 4, i18n("icmp_v4_msgs.type_3_4_fragmentation_required") },
   { 3, 6, i18n("icmp_v4_msgs.type_3_6_destination_network_unknown") },
   { 3, 7, i18n("icmp_v4_msgs.type_3_7_destination_host_unknown") },
   { 3, 0, i18n("icmp_v4_msgs.type_3_0_destination_unreachable") },
   { 4, 0, i18n("icmp_v4_msgs.type_4_0_source_quench") },
   { 5, 0, i18n("icmp_v4_msgs.type_5_0_redirect") },
   { 8, 0, i18n("icmp_v4_msgs.type_8_0_echo_request") },
   { 9, 0, i18n("icmp_v4_msgs.type_9_0_router_advertisement") },
   { 10, 0, i18n("icmp_v4_msgs.type_10_0_router_selection") },
   { 11, 0, i18n("icmp_v4_msgs.type_11_0_ttl_expired_in_transit") },
   { 11, 1, i18n("icmp_v4_msgs.type_11_1_fragment_reassembly_time_exceeded") },
   { 12, 0, i18n("icmp_v4_msgs.type_12_0_parameter_problem") },
   { 13, 0, i18n("icmp_v4_msgs.type_13_0_timestamp_request") },
   { 14, 0, i18n("icmp_v4_msgs.type_14_0_timestamp_reply") },
   { 15, 0, i18n("icmp_v4_msgs.type_15_0_information_request") },
   { 16, 0, i18n("icmp_v4_msgs.type_16_0_information_reply") },
   { 17, 0, i18n("icmp_v4_msgs.type_17_0_address_mask_request") },
   { 18, 0, i18n("icmp_v4_msgs.type_18_0_address_mask_reply") },
   { 30, 0, i18n("icmp_v4_msgs.type_30_0_traceroute") },
}

local icmp_v6_msgs = {
   { 1, 0,  i18n("icmp_v6_msgs.type_1_0_destination_unreachable") },
   { 2, 0,  i18n("icmp_v6_msgs.type_2_0_packet_too_big") },
   { 3, 0, i18n("icmp_v6_msgs.type_3_0_hop_limit_exceeded_in_transit") },
   { 3, 1, i18n("icmp_v6_msgs.type_3_1_fragment_reassembly_time_exceeded") },
   { 4, 0, i18n("icmp_v6_msgs.type_4_0_parameter_problem") },
   { 128, 0, i18n("icmp_v6_msgs.type_128_0_echo_request") },
   { 129, 0, i18n("icmp_v6_msgs.type_129_0_echo_reply") },
   { 133, 0, i18n("icmp_v6_msgs.type_133_0_router_solicitation") },
   { 134, 0, i18n("icmp_v6_msgs.type_134_0_router_advertisement") },
   { 135, 0, i18n("icmp_v6_msgs.type_135_0_neighbor_solicitation") },
   { 136, 0, i18n("icmp_v6_msgs.type_136_0_neighbor_advertisement") },
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
	    
	    print("</td><td align=right>".. (value.sent+value.rcvd) .."</td></tr>\n")
	 end
      end
   end
end
