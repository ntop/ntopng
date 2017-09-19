--
-- (C) 2013-17 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local discover = require "discover_utils"

local ifId = getInterfaceId(ifname)

local refresh_button = '<small><a href="'..ntop.getHttpPrefix()..'/lua/discover.lua?request_discovery=true" title="Refresh"><i class="fa fa-refresh fa-sm" aria-hidden="true"></i></a></small>'

if _GET["request_discovery"] == "true" then
   refresh_button = ""
   discover.requestNetworkDiscovery(ifId)
end

local discovery_requested = discover.networkDiscoveryRequested(ifId)

if discovery_requested then
   refresh_button = ""
end

sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- print('<hr><H2>'..i18n("discover.network_discovery")..'&nbsp;</H2><br>')
print('<hr><H2>'..i18n("discover.network_discovery")..'&nbsp;'..refresh_button..'</H2><br>')

print("<script>setTimeout(function(){window.location.href='"..ntop.getHttpPrefix().."/lua/discover.lua'}, 30000);</script>")

local discovered = discover.discover2table(ifname)

if discovery_requested then
   print('<div class=\"alert alert-info alert-dismissable\"><i class="fa fa-info-circle fa-lg"></i>&nbsp;'..i18n('discover.network_discovery_not_enabled', {url=ntop.getHttpPrefix().."/lua/admin/prefs.lua?tab=discovery", flask_icon="<i class=\"fa fa-flask\"></i>"})..'</div>')

elseif discovered["status"]["code"] == "NOCACHE" then
   -- nothing to show and nothing has been requested
   print('<div class=\"alert alert-info alert-dismissable\"><i class="fa fa-info-circle fa-lg"></i>&nbsp;'..discovered["status"]["message"]..'</div>')
end

if discovered["status"]["code"] == "ERROR" then
   print('<div class=\"alert alert-danger\"><i class="fa fa-warning fa-lg"></i>&nbsp;'..discovered["status"]["message"]..'</div>')

elseif discovered["status"]["code"] == "OK" then -- everything is ok
   print("<table class=\"table table-bordered table-striped\">")

   print("<tr><th>"..i18n("discover.network_discovery_datetime").."</th><td colspan=6>"..formatEpoch(discovered["discovery_timestamp"]).."</td></tr>")

   print("<tr><th>"..i18n("ip_address").."</th><th>"..i18n("name").."</th><th>"..i18n("mac_stats.manufacturer").."</th><th>"..i18n("mac_address").."</th>")
   print("<th>"..i18n("os").."</th><th>"..i18n("info").."</th><th>"..i18n("discover.device").."</th></tr>")

   for _, el in ipairs(discovered["devices"] or {}) do
      print("<tr>")
      -- IP
      print("<td align=left nowrap>")
      print("<a href='" .. ntop.getHttpPrefix().. "/lua/host_details.lua?host="..tostring(el["ip"]).."'>"..tostring(el["ip"]).."</A>")
      if el["icon"] then print(el["icon"] .. "&nbsp;") end
      if el["ghost"] then print(' <font color=red>'..discover.ghost_icon..'</font>') end
      print("</td>\n")

      -- Name
      print("<td>")
      if el["sym"] then print(el["sym"]) end
      if el["symIP"] then
	 if el["sym"] then
	    print(" ["..el["symIP"].."]")
	 else
	    print(el["symIP"])
	 end
      end
      print("</td>\n")

      -- Manufacturer
      print("<td>")
      if el["manufacturer"] then
	 print(el["manufacturer"])
      else
	 print(get_manufacturer_mac(el["mac"]))
      end
      if el["modelName"] then print(" ["..el["modelName"].."]") end
      print("</td>\n")

      -- Mac
      print("<td align=\"center\">")
      print("<A HREF='"..ntop.getHttpPrefix().. "/lua/mac_details.lua?host="..el["mac"].."'>"..el["mac"].."</A> ")
      print("</td>\n")

      -- OS
      print("<td>")
      local mac_info = interface.getMacInfo(el.mac, 0) -- 0 = vlanId
      if(mac_info ~= nil) then print(getOperatingSystemIcon(mac_info.operatingSystem)) else print("&nbsp;") end
      print("</td>\n")
      
      -- Information
      print("<td>")
      if el["information"] then print(table.concat(el["information"], "<br>")) end
      if el["url"] then
	 if el["information"] then
	    print("<br>"..el["url"])
	 else
	    print(el["url"])
	 end
      end
      print("</td>\n")

      -- Device
      print("<td>")
      if el["device_label"] then print(el["device_label"]) end
      print("</td>\n")

      print("</tr>")
   end
end
print("</table>\n")

if(discovered["ghost_found"]) then
   print('<b>NOTE</b>: The <font color=red>'..discover.ghost_icon..'</font> icon highlights ghost hosts (i.e. they do not belong to the interface IP address network).')
end



dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
