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
local discover = require "discover_utils"
local host_pools_utils = require "host_pools_utils"

local host_info = url2hostinfo(_GET)

mac         = host_info["host"]
vlanId      = host_info["vlan"]

if isAdministrator() then
   if(_POST["custom_name"] ~=nil) then
      setHostAltName(mac, _POST["custom_name"])
   end

   if(_POST["device_type"] ~=nil) then
      local devtype = tonumber(_POST["device_type"])
      setCustomDeviceType(mac, devtype)
      interface.setMacDeviceType(mac, devtype, true --[[ overwrite ]])
   end
end

if(vlanId == nil) then vlanId = 0 end

interface.select(ifname)
ifstats = interface.getStats()
ifId = ifstats.id
prefs = ntop.getPrefs()

sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(mac == nil) then
   print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png>" .. " " .. i18n("mac_details.mac_parameter_missing_message") .. "</div>")
   return
end

mac_info = interface.getMacInfo(mac, vlanId)

-- tprint(mac_info)

if(mac_info == nil) then
      print('<div class=\"alert alert-danger\"><i class="fa fa-warning fa-lg"></i>'..' '..i18n("mac_details.mac_cannot_be_found_message",{mac=mac}))
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

print("<li><a href=\"#\">"..i18n("mac_details.mac")..": "..mac.."</A> </li>")
   print("<li class=\"active\"><a href=\"#\"><i class=\"fa fa-home fa-lg\"></i>\n")

   print("<li><a href='javascript:history.go(-1)'><i class='fa fa-reply'></i></a></li></ul></div></nav></div>")

print("<table class=\"table table-bordered table-striped\">\n")
print("<tr><th width=35%>"..i18n("mac_address").."</th><td> "..mac)

s = get_symbolic_mac(mac, true)
if(s ~= mac) then 
     print(" ("..s..")")
end

local label = getHostAltName(mac)

if mac_info["num_hosts"] > 0 then
   print(" [ <A HREF=\"".. ntop.getHttpPrefix().."/lua/hosts_stats.lua?mac="..mac.."\">"..i18n("details.show_hosts").."</A> ]")
end

print("</td>")
if(isAdministrator()) then
       print("<td>")

       print [[<form class="form-inline" style="margin-bottom: 0px;" method="post">]]
       print[[<input type="text" name="custom_name" placeholder="Custom Name" value="]]
      if(label ~= nil) then print(label) end
      print("\"></input> &nbsp;")

discover.printDeviceTypeSelector(mac_info.devtype, "device_type")

print [[
	 &nbsp;<button  type="submit" class="btn btn-default">]] print(i18n("save")) print[[</button>]]
print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
print [[</form>
</td></tr>
   ]]
    else
--       print("<td>&nbsp;</td></tr>")
    end


print("</td></tr>")

if isAdministrator() then
   local pool_id = nil

   if (_POST["pool"] ~= nil) then
      pool_id = _POST["pool"]
      local prev_pool = host_pools_utils.getMacPool(mac)

      if pool_id ~= prev_pool then
         local key = mac
         if not host_pools_utils.changeMemberPool(ifId, key, pool_id) then
            pool_id = nil
         else
            interface.reloadHostPools()
         end
      end
   end

   if (pool_id == nil) then
      pool_id = host_pools_utils.getMacPool(mac)
   end

   if not ifstats.isView then
      printPoolChangeDropdown(pool_id)
   end
end

if(mac_info.devtype ~= 0) then
   -- This is a known device type
   print("<tr><th>".. i18n("details.device_type") .. "</th><td>" .. discover.devtype2icon(mac_info.devtype) .. " ")
   print(discover.devtype2string(mac_info.devtype) .. "</td><td></td></tr>\n")
end

print("<tr><th>".. i18n("details.first_last_seen") .. "</th><td nowrap><span id=first_seen>" .. formatEpoch(mac_info["seen.first"]) ..  " [" .. secondsToTime(os.time()-mac_info["seen.first"]) .. " " .. i18n("details.ago").."]" .. "</span></td>\n")
print("<td  width='35%'><span id=last_seen>" .. formatEpoch(mac_info["seen.last"]) .. " [" .. secondsToTime(os.time()-mac_info["seen.last"]) .. " " .. i18n("details.ago").."]" .. "</span></td></tr>\n")

if((mac_info["bytes.sent"]+mac_info["bytes.rcvd"]) > 0) then
   print("<tr><th>" .. i18n("details.sent_vs_received_traffic_breakdown") .. "</th><td colspan=2>")
   breakdownBar(mac_info["bytes.sent"], i18n("sent"), mac_info["bytes.rcvd"], i18n("details.rcvd"), 0, 100)
   print("</td></tr>\n")
end

print("<tr><th>" .. i18n("details.traffic_sent_received") .. "</th><td><span id=pkts_sent>" .. formatPackets(mac_info["packets.sent"]) .. "</span> / <span id=bytes_sent>".. bytesToSize(mac_info["bytes.sent"]) .. "</span> <span id=sent_trend></span></td><td><span id=pkts_rcvd>" .. formatPackets(mac_info["packets.rcvd"]) .. "</span> / <span id=bytes_rcvd>".. bytesToSize(mac_info["bytes.rcvd"]) .. "</span> <span id=rcvd_trend></span></td></tr>\n")
print([[
<tr>
   <th rowspan="2"><A HREF=https://en.wikipedia.org/wiki/Address_Resolution_Protocol>]]) print(i18n("details.address_resolution_protocol")) print[[</A></th>
   <th>]] print(i18n("details.arp_requests")) print[[</th>
   <th>]] print(i18n("details.arp_replies")) print([[</th>
</tr>
<tr>
   <td>]]..formatValue(mac_info["arp_requests.sent"])..[[ ]]..i18n("sent")..[[ / ]]..formatValue(mac_info["arp_requests.rcvd"])..[[ ]]..i18n("received")..[[</td>
   <td>]]..formatValue(mac_info["arp_replies.sent"])..[[ ]]..i18n("sent")..[[ / ]]..formatValue(mac_info["arp_replies.rcvd"])..[[ ]]..i18n("received")..[[</td>
</tr>]])

print("</table>")

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
