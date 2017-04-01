--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   require "snmp_utils"
end

require "lua_utils"
require "graph_utils"
require "alert_utils"
require "historical_utils"

local host_info = url2hostinfo(_GET)

mac         = host_info["host"]
vlanId      = host_info["vlan"]

if(vlanId == nil) then vlanId = 0 end

interface.select(ifname)
ifstats = interface.getStats()
ifId = ifstats.id
prefs = ntop.getPrefs()

sendHTTPHeader('text/html; charset=iso-8859-1')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(mac == nil) then
   print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Mac parameter is missing (internal error ?)</div>")
   return
end

mac_info = interface.getMacInfo(mac, vlanId)

if(mac_info == nil) then
      print('<div class=\"alert alert-danger\"><i class="fa fa-warning fa-lg"></i> Mac '.. mac  .. ' cannot be found. ')
      print("</div>")
      dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
      return
end

print [[
<div class="bs-docs-example">
            <nav class="navbar navbar-default" role="navigation">
              <div class="navbar-collapse collapse">
<ul class="nav navbar-nav">
]]

print("<li><a href=\"#\">Mac: "..mac.."</A> </li>")
   print("<li class=\"active\"><a href=\"#\"><i class=\"fa fa-home fa-lg\"></i>\n")

print("<li><a href=\""..ntop.getHttpPrefix().."/lua/mac_stats.lua\"><i class='fa fa-reply'></i></a></li></ul></div></nav></div>")

print("<table class=\"table table-bordered table-striped\">\n")
print("<tr><th width=35%>MAC Address</th><td> "..mac)

s = get_symbolic_mac(mac, true)
if(s ~= mac) then 
     print(" ("..s..")")
end

if(_POST["custom_name"] ~=nil) then
 setHostAltName(mac, _POST["custom_name"])
end

if(_POST["custom_icon"] ~=nil) then
 setHostIcon(mac, _POST["custom_icon"])
end

print(getHostIcon(mac))

local label = getHostAltName(mac)

if mac_info["num_hosts"] > 0 then
   print(" [ <A HREF=\"".. ntop.getHttpPrefix().."/lua/hosts_stats.lua?mac="..mac.."\">Show Hosts</A> ]")
end

print("</td>")
if(isAdministrator()) then
       print("<td>")

       print [[<form class="form-inline" style="margin-bottom: 0px;" method="post">]]
       print[[<input type="text" name="custom_name" placeholder="Custom Name" value="]]
      if(label ~= nil) then print(label) end
      print("\"></input>")

pickIcon(mac)

print [[
	 &nbsp;<button  type="submit" class="btn btn-default">Save</button>]]
print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
print [[</form>
</td></tr>
   ]]
    else
--       print("<td>&nbsp;</td></tr>")
    end


print("</td></tr>")


print("<tr><th>First / Last Seen</th><td nowrap><span id=first_seen>" .. formatEpoch(mac_info["seen.first"]) ..  " [" .. secondsToTime(os.time()-mac_info["seen.first"]) .. " ago]" .. "</span></td>\n")
print("<td  width='35%'><span id=last_seen>" .. formatEpoch(mac_info["seen.last"]) .. " [" .. secondsToTime(os.time()-mac_info["seen.last"]) .. " ago]" .. "</span></td></tr>\n")

if((mac_info["bytes.sent"]+mac_info["bytes.rcvd"]) > 0) then
   print("<tr><th>Sent vs Received Traffic Breakdown</th><td colspan=2>")
   breakdownBar(mac_info["bytes.sent"], "Sent", mac_info["bytes.rcvd"], "Rcvd", 0, 100)
   print("</td></tr>\n")
end

print("<tr><th>Traffic Sent / Received</th><td><span id=pkts_sent>" .. formatPackets(mac_info["packets.sent"]) .. "</span> / <span id=bytes_sent>".. bytesToSize(mac_info["bytes.sent"]) .. "</span> <span id=sent_trend></span></td><td><span id=pkts_rcvd>" .. formatPackets(mac_info["packets.rcvd"]) .. "</span> / <span id=bytes_rcvd>".. bytesToSize(mac_info["bytes.rcvd"]) .. "</span> <span id=rcvd_trend></span></td></tr>\n")
print([[
<tr>
   <th rowspan="2"><A HREF=https://en.wikipedia.org/wiki/Address_Resolution_Protocol>Address Resolution Protocol</A></th>
   <th>ARP Requests</th>
   <th>ARP Replies</th>
</tr>
<tr>
   <td>]]..mac_info["arp_requests.sent"]..[[ Sent / ]]..mac_info["arp_requests.rcvd"]..[[ Received</td>
   <td>]]..mac_info["arp_replies.sent"]..[[ Sent / ]]..mac_info["arp_replies.rcvd"]..[[ Received</td>
</tr>]])

print("</table>")

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
