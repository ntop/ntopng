--
-- (C) 2013-17 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local discover = require "discover_utils"
local discovery_enabled = (ntop.getPref("ntopng.prefs.is_device_discovery_enabled") == "1")

sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print('<hr><H2>'..i18n("discover.network_discovery")..'&nbsp;</H2><br>')
-- print('<hr><H2>'..i18n("discover.network_discovery")..'&nbsp;<small><a href="'..ntop.getHttpPrefix()..'/lua/discover.lua?discovery_recache=true" title="Refresh"><i class="fa fa-refresh fa-sm" aria-hidden="true"></i></a></small></H2><br>')

if discovery_enabled == false then
   print('<div class=\"alert alert-info\"><i class="fa fa-info-circle fa-lg"></i>&nbsp;'..i18n('discover.device_discovery_not_enabled', {url=ntop.getHttpPrefix().."/lua/admin/prefs.lua?tab=discovery", flask_icon="<i class=\"fa fa-flask\"></i>"})..'</div>')

else

local discovered = discover.discover2table(ifname, _GET["discovery_recache"] == "true")

if discovered["status"]["code"] ~= "OK" then
   print('<div class=\"alert alert-danger\"><i class="fa fa-warning fa-lg"></i>'..discovered["status"]["message"]..'</div>')

else
   print("<table class=\"table table-bordered table-striped\">\n<tr><th>"..i18n("ip_address").."</th><th>"..i18n("name").."</th><th>"..i18n("mac_stats.manufacturer").."</th><th>"..i18n("mac_address").."</th>")
   print("<th>"..i18n("info").."</th><th>"..i18n("discover.device").."</th></tr>")

   for _, el in ipairs(discovered["devices"] or {}) do
      print("<tr>")
      -- IP
      print("<td align=left nowrap>")
      print("<a href='" .. ntop.getHttpPrefix().. "/lua/host_details.lua?host="..tostring(el["ip"]).."'>"..tostring(el["ip"]).."</A>")
      if el["icon"] then print(el["icon"] .. "&nbsp;") end
      if el["ghost"] then print(' <font color=red>'..discover.ghost_icon..'</font>') end
      print("</td>")

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
      print("</td>")

      -- Manufacturer
      print("<td>")
      if el["manufacturer"] then print(el["manufacturer"]) end
      if el["modelName"] then
	 if el["manufacturer"] then
	    print(" ["..el["modelName"].."]")
	 else
	    print(el["modelName"])
	 end
      end
      print("</td>")

      -- Mac
      print("<td>")
      print("<A HREF='"..ntop.getHttpPrefix().. "/lua/mac_details.lua?host="..el["mac"].."'>"..el["mac"].."</A>")
      print("</td>")

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
      print("</td>")

      -- Device
      print("<td>")
      if el["device_label"] then print(el["device_label"]) end
      print("</td>")

      print("</tr>")
   end
end

if false then -- TODO: remove
   print("<p>&nbsp;<H2>"..ifname.." Network Discovery</H2><p>&nbsp;<p>\n")
   print("<table class=\"table table-bordered table-striped\">\n<tr><th>IP</th><th>Name</th><th>Manufacturer</th><th>MAC</th>")
   if(show_services) then print("<th>Services</th>") end
   print("<th>Information</th><th>Device</th></tr>")

   for mac,ip in pairsByValues(arp_mdns, asc) do
      if((string.find(mac, ":") ~= nil)
	    and (ip ~= "0.0.0.0")
	 and (ip ~= "255.255.255.255")) then
	 -- This is an ARP entry
	 local deviceType
	 local symIP = mdns[ip]
	 local services = ""
	 local host = interface.getHostInfo(ip, 0) -- no VLAN
	 local sym

	 if(host ~= nil) then sym = host["name"] else sym = ntop.resolveName(ip) end

	 print("<tr><td align=left nowrap>")

	 print("<a href=" .. ntop.getHttpPrefix().. "/lua/host_details.lua?host="..ip..">"..ip.."</A>")
	 if(ssdp[ip] and ssdp[ip].icon) then print(ssdp[ip].icon .. "&nbsp;") end

	 if(ghost_macs[mac] ~= nil) then
	    print(' <font color=red>'..discover.ghost_icon..'</font>')
	 end

	 print("</td><td>")
	 if((sym ~= "") and (sym ~= ip)) then print(sym) end

	 if(symIP ~= nil) then
	    if((sym ~= "") and (symIP ~= ip) and (sym ~= ip)) then
	       print(" ["..symIP.."]")
	    else
	       print(symIP)
	    end
	 else
	    print("&nbsp;")
	 end

	 print("</td><td align=left>")
	 if(ssdp[ip] and ssdp[ip].manufacturer) then
	    manufacturer = ssdp[ip].manufacturer
	 else
	    manufacturer = get_manufacturer_mac(mac)
	 end

	 print(manufacturer)
	 if(ssdp[ip] and ssdp[ip]["modelName"]) then print(" ["..ssdp[ip]["modelName"].."]") end
	 print("</td><td><A HREF="..ntop.getHttpPrefix().. "/lua/mac_details.lua?host="..mac..">"..mac.."</A>")

	 print("</td><td>INFORMATION ")

	 if(ssdp[ip] ~= nil or arp_mdns[ip] ~= nil) then
	    if(show_services) then
	       if(ssdp[ip].services ~= nil) then
		  for i, name in ipairs(ssdp[ip].services) do
		     if(i > 1) then print("<br>") end
		     print(name)
		     services = services .. ";" .. name
		  end
	       end

	       print("</td><td>")
	    end

	    if(arp_mdns[ip] ~= nil) then
	       local s = string.split(arp_mdns[ip], ";")

	       if(s ~= nil) then
		  for i,name in pairs(s) do
		     if(i > 1) then print(" --- <br>") end
		     print(name)
		  end
	       end
	    end
	    if(ssdp[ip] ~= nil and ssdp[ip].url ~= nil) then print(ssdp[ip].url .. "&nbsp;") end
	 else
	    if(show_services) then
	       print("&nbsp;</td><td>&nbsp;")
	    end
	 end

	 deviceType,deviceLabel = findDevice(ip, mac, manufacturer, arp_mdns[ip], services, ssdp[ip], mdns, snmp[ip], osx_devices[ip], sym)
	 if(deviceLabel == "") then
	    local mac_info = interface.getMacInfo(mac, 0) -- 0 = VLAN
	    deviceLabel = deviceLabel .. discover.devtype2icon(mac_info.devtype)
	 end
	 print("</td><td>"..deviceLabel.."</td></tr>\n")
	 interface.setMacDeviceType(mac, discover.devtype2id(deviceType), false) -- false means don't overwrite if already set to ~= unknown
      end
   end

end -- TODO: remove

print("</table>\n")

if(discovered["ghost_found"]) then
   print('<b>NOTE</b>: The <font color=red>'..discover.ghost_icon..'</font> icon highlights ghost hosts (i.e. they do not belong to the interface IP address network).')
end

end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
