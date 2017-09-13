--
-- (C) 2013-17 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local discover = require "discover_utils"

sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- ################################################################################

local function getbaseURL(url)
   local name = url:match( "([^/]+)$" )

   if((name == "") or (name == nil)) then
      return(url)
   else
      return(string.sub(url, 1, string.len(url)-string.len(name)-1))
   end
end

-- ################################################################################

local function findDevice(ip, mac, manufacturer, _mdns, ssdp_str, ssdp_entries, names, snmp, osx, symName)
   local mdns = { }
   local ssdp = { }
   local str
   local friendlyName = ""

   if((ssdp_entries ~= nil)and (ssdp_entries.friendlyName ~= nil)) then
      friendlyName = ssdp_entries["friendlyName"]
   end

   if((names == nil) or (names[ip] == nil)) then
      hostname = ""
   else
      hostname = string.lower(names[ip])
   end

   if(symName == nil) then symName = "" else symName = string.lower(symName) end

   if(_mdns ~= nil) then
      --io.write(mac .. " /" .. manufacturer .. " / ".. _mdns.."\n")
      local mdns_items = string.split(_mdns, ";")

      if(mdns_items == nil) then
	 mdns[_mdns] = 1
      else
	 for _,v in pairs(mdns_items) do
	    mdns[v] = 1
	 end
      end
   end

   if(ssdp_str ~= nil) then
      --io.write(mac .. " /" .. manufacturer .. " / ".. ssdp_str.."\n")

      local ssdp_items = string.split(ssdp_str, ";")

      if(ssdp_items == nil) then
	 ssdp[ssdp_str] = 1
      else
	 for _,v in pairs(ssdp_items) do
	    ssdp[v] = 1
	 end
      end
   end

   if(osx ~= nil) then
      -- model=iMac11,3;osxvers=16
      local elems = string.split(osx, ';')

      if((elems == nil) and string.contains(osx, "model=")) then
	 elems = {}
	 table.insert(elems, osx)
      end

      if(elems ~= nil) then
	 local model   = string.split(elems[1], '=')
	 local osxvers = nil

	 if(discover.apple_products[model[2]] ~= nil) then
	    model = discover.apple_products[model[2]]
	    if(model == nil) then model = "" end
	 else
	    model = model[2]
	 end

	 if(elems[2] ~= nil) then
	    local osxvers = string.split(elems[2], '=')
	    if(discover.apple_osx_versions[osxvers[2]] ~= nil) then
	       osxvers = discover.apple_osx_versions[osxvers[2]]
	       if(osxvers == nil) then osxvers = "" end
	    else
	       osxvers = osxvers[2]
	    end
	 end
	 osx = "<br>"..model

	 if(osxvers ~= nil) then osx = osx .."<br>"..osxvers end
      end
   end

   if(mdns["_ssh._tcp.local"] ~= nil) then
      local icon = 'workstation'
      local ret

      if(osx ~= nil) then
	 if(string.contains(osx, "MacBook")) then
	    icon = 'laptop'
	 end
      end

      ret = '</i>'..discover.asset_icons[icon]..' ' .. discover.apple_icon

      if(osx ~= nil) then ret = ret .. osx end
      return icon, ret
   elseif(mdns["_nvstream_dbd._tcp.local"] ~= nil) then
      return 'workstation', discover.asset_icons['workstation']..' (Windows)'
   elseif(mdns["_workstation._tcp.local"] ~= nil) then
      return 'workstation', discover.asset_icons['workstation']..' (Linux)'
   end

   if(string.contains(friendlyName, "TV")) then
      return 'tv', discover.asset_icons['tv']
   end

   if((ssdp["urn:upnp-org:serviceId:AVTransport"] ~= nil)
      or (ssdp["urn:upnp-org:serviceId:RenderingControl"] ~= nil)) then
      return 'multimedia', discover.asset_icons['multimedia']
   end

   if(ssdp_entries and ssdp_entries["modelDescription"]) then
	local descr = string.lower(ssdp_entries["modelDescription"])

	if(string.contains(descr, "camera")) then
	   return 'video', discover.asset_icons['video']
	elseif(string.contains(descr, "router")) then
	   return 'networking', discover.asset_icons['networking']
	end
   end

   io.write("[manufacturer] "..manufacturer.."\n")
   if(string.contains(manufacturer, "Oki Electric") and (snmp ~= nil)) then
      return 'printer', discover.asset_icons['printer'].. ' ('..snmp..')'
   elseif(string.contains(manufacturer, "Hikvision")) then
      return 'video', discover.asset_icons['video']
   elseif(string.contains(manufacturer, "Super Micro")) then
      return 'workstation', discover.asset_icons['workstation']
   elseif(string.contains(manufacturer, "Raspberry")) then
      return 'workstation', discover.asset_icons['workstation']
   elseif(string.contains(manufacturer, "Juniper Networks")) then
      return 'networking', discover.asset_icons['networking']
   elseif(string.contains(manufacturer, "Cisco")) then
      return 'networking', discover.asset_icons['networking']
   elseif(string.contains(manufacturer, "Palo Alto Networks")) then
      return 'networking', discover.asset_icons['networking']
   elseif(string.contains(manufacturer, "Liteon Technology")) then
      return 'workstation', discover.asset_icons['workstation']
   elseif(string.contains(manufacturer, 'TP%-LINK')) then -- % is the escape char in Lua
      return 'wifi', discover.asset_icons['wifi']
   elseif(string.contains(manufacturer, 'Broadband')) then -- % is the escape char in Lua
      return 'networking', discover.asset_icons['networking']
   elseif(string.contains(manufacturer, "Samsung Electronics")
	  or string.contains(manufacturer, "SAMSUNG ELECTRO")
	  or string.contains(manufacturer, "HTC Corporation")
	  or string.contains(manufacturer, "HUAWEI")
	  or string.contains(manufacturer, "Xiaomi Communications")
	  or string.contains(manufacturer, "Mobile Communications") -- LG Electronics (Mobile Communications)
	) then
      return 'phone', discover.asset_icons['phone'].. ' ' ..discover.android_icon
   elseif(string.contains(manufacturer, "Hewlett Packard") and (snmp ~= nil)) then
      local _snmp = string.lower(snmp)

      if(string.contains(_snmp, "jet") or string.contains(_snmp, "fax")) then
	 return 'printer', discover.asset_icons['printer']..' ('..snmp..')'
      elseif(string.contains(_snmp, "curve")) then
	 return 'networking', discover.asset_icons['networking']..' ('..snmp..')'
      else
	 return 'workstation', discover.asset_icons['workstation']..' ('..snmp..')'
      end
   elseif(string.contains(manufacturer, "Xerox") and (snmp ~= nil)) then
      return 'printer', discover.asset_icons['printer']..' ('..snmp..')'
   elseif(string.contains(manufacturer, "Apple, Inc.")) then
      if(string.contains(hostname, "iphone") or string.contains(symName, "iphone")) then
	 return 'phone', discover.asset_icons['phone']..' ('  .. discover.apple_icon .. ' iPhone)'
      elseif(string.contains(hostname, "ipad") or string.contains(symName, "ipad")) then
	 return 'tablet', discover.asset_icons['tablet']..' ('  .. discover.apple_icon .. 'iPad)'
      elseif(string.contains(hostname, "ipod") or string.contains(symName, "ipod")) then
	 return 'phone', discover.asset_icons['phone']..' ('  .. discover.apple_icon .. 'iPod)'
      else
	 local ret = '</i> '..discover.asset_icons['workstation']..' ' .. discover.apple_icon
	 local sym = names[ip]
	 local what = 'workstation'

	 if(sym == nil) then sym = "" else sym = string.lower(sym) end

	 if((snmp and string.contains(snmp, "capsule"))
	       or string.contains(sym, "capsule"))
	 then
	    ret = '</i> '..discover.asset_icons['nas']
	    what = 'nas'
	 elseif(string.contains(sym, "book")) then
	    ret = '</i> '..discover.asset_icons['laptop']..' ' .. discover.apple_icon
	    what = 'laptop'
	 end

	 if(snmp ~= nil) then ret = ret .. " ["..snmp.."]" end
	 return what, ret
      end
   end

   if(string.contains(mac, "F0:4F:7C") and string.contains(hostname, "kindle-")) then
      return 'tablet', discover.asset_icons['tablet']..' (Kindle)'
   end

   if(names["gateway.local"] == ip) then
      return 'networking', discover.asset_icons['networking']
   end

   if(string.starts(hostname, "desktop-") or string.starts(symName, "desktop-")) then
      return 'workstation', discover.asset_icons['workstation']..' (Windows)'
   elseif(string.contains(hostname, "thinkpad") or string.contains(symName, "thinkpad")) then
      return 'laptop', discover.asset_icons['laptop']
   elseif(string.contains(hostname, "android") or string.contains(symName, "android")) then
      return 'phone', discover.asset_icons['phone']..' ' ..discover.android_icon
   elseif(string.contains(hostname, "%-NAS") or string.contains(symName, "%-NAS")) then
      return 'nas', discover.asset_icons['nas']
   end

   if(snmp ~= nil) then
      if(string.contains(snmp, "router")
	    or string.contains(snmp, "switch")
      ) then
	 return 'networking', discover.asset_icons['networking']..' ('..snmp..')'
      elseif(string.contains(snmp, "air")) then
	 return 'wifi', discover.asset_icons['wifi']..' ('..snmp..')'
      else
	 return 'unknown', snmp
      end
   end

   if(string.contains(manufacturer, "Ubiquity")) then
      return 'networking', discover.asset_icons['networking']
   end

   return 'unknown', ""
end

-- #############################################################################

local function analyzeSSDP(ssdp)
   local rsp = {}

   for url,host in pairs(ssdp) do
      local hresp = ntop.httpGet(url, "", "", 3 --[[ seconds ]])
      local manufacturer = ""
      local modelDescription = ""
      local modelName = ""
      local icon = ""
      local base_url = getbaseURL(url)
      local services = { }
      local friendlyName = ""

      if(hresp ~= nil) then
	 local xml = require("xmlSimple").newParser()
	 local r = xml:ParseXmlText(hresp["CONTENT"])

	 if(r.root ~= nil) then
	    if(r.root.device ~= nil) then
	       if(r.root.device.friendlyName ~= nil) then
		  friendlyName = r.root.device.friendlyName:value()
	       end
	       if(r.root.device.modelName ~= nil) then
		  modelName = r.root.device.modelName:value()
	       end
	       if(r.root.device.modelDescription ~= nil) then
		  modelDescription = r.root.device.modelDescription:value()
	       end
	    end
	 end

	 if(r.root ~= nil) then
	    if(r.root.device ~= nil) then
	       if(r.root.device.manufacturer ~= nil) then
		  manufacturer = r.root.device.manufacturer:value()
	       end

	       if(r.root.device.serviceList ~= nil) then
		  local k,v
		  local serviceList = r.root.device.serviceList:children()

		  for k,v in pairs(serviceList) do
		     if(v.serviceId ~= nil) then
			io.write(v.serviceId:value().."\n")

			table.insert(services, v.serviceId:value())
		     end
		  end
	       end

	       if(r.root.device.iconList ~= nil) then
		  local k,v
		  local iconList = r.root.device.iconList:children()
		  local lastwidth = 999

		  for k,v in pairs(iconList) do
		     if((v.mimetype ~= nil) and (v.width ~= nil) and (v.url ~= nil)) then
			local mime = v.mimetype:value()
			local width = tonumber(v.width:value())

			if(width <= lastwidth) then
			   if((mime == "image/jpeg") or (mime == "image/png") or (mime == "image/gif")) then
			      icon = "<img src="..base_url..v.url:value()..">"
			      lastwidth = width -- Pick the smallest icon
			   end
			end
		     end
		  end
	       end
	    end
	 end

	 -- io.write(hresp["CONTENT"].."\n")
      end

      if(rsp[host] ~= nil) then
	 rsp[host].url = rsp[host].url .. "<br><A HREF="..url..">"..friendlyName.."</A>"

	 for _,v in ipairs(services) do
	    table.insert(rsp[host].services, v)
	 end
      else
	 rsp[host] = { ["icon"] = icon, ["manufacturer"] = manufacturer, ["url"] = "<A HREF="..url..">"..friendlyName.."</A>",
	    ["services"] = services, ["modelName"] = modelName,
	    ["modelDescription"] = modelDescription, ["friendlyName"] = friendlyName }
      end

      -- io.write(rsp[host].icon .. " / " ..rsp[host].manufacturer .. " / " ..rsp[host].url .. " / " .. "\n")
   end

   return rsp
end

-- ################################################################################

local function discoverStatus(code, message)
   return {code = code or '', message = message or ''}

end

-- #############################################################################

local function discoverARP()
   io.write("Starting ARP discovery...\n")
   local status = discoverStatus("OK")
   local res = {}

   local ghost_macs  = {}
   local ghost_found = false
   local arp_mdns = interface.arpScanHosts()


   if(arp_mdns == nil) then
      status = discoverStatus("ERROR", i18n("discover.err_unable_to_arp_discovery"))
   else
      -- Add the known macs to the list
      local known_macs = interface.getMacsInfo(nil, 999, 0, false, 0, tonumber(vlan), true, true, nil) or {}

      for _,hmac in pairs(known_macs.macs) do
	 if(hmac["bytes.sent"] > 0) then -- Skip silent hosts
	    if(arp_mdns[hmac.mac] == nil) then
	       local ips = interface.findHostByMac(hmac.mac) or {}
	       -- io.write("Missing MAC "..hmac.mac.."\n")

	       for k,v in pairs(ips) do
		  arp_mdns[hmac.mac] = k
		  ghost_macs[hmac.mac] = k
		  ghost_found = true
	       end
	    end
	 end
      end
   end

   return {status = status, ghost_macs = ghost_macs, ghost_found = ghost_found, arp_mdns = arp_mdns}
end

-- #############################################################################

local function discover2table(interface_name)
   interface.select(interface_name)

   -- ARP
   local arp_d = discoverARP()
   if arp_d["status"]["code"] ~= "OK" then
      return {status = arp_d["status"]}
   end

   local arp_mdns = arp_d["arp_mdns"] or {}
   local ghost_macs = arp_d["ghost_macs"]
   local ghost_found = arp_d["ghost_found"]

   -- SSDP, MDNS and SNMP
   io.write("Starting SSDP discovery...\n")
   local ssdp = interface.discoverHosts(3)
   local osx_devices = {}

   for mac,ip in pairsByValues(arp_mdns, asc) do
      if((ip == "0.0.0.0") or (ip == "255.255.255.255")) then
	 -- This does not look like a good IP/MAC combination
      elseif(string.find(mac, ":") ~= nil) then
	 local manufacturer = get_manufacturer_mac(mac)

	 -- This is an ARP entry
	 -- io.write("Attempting to resolve "..ip.."\n")
	 interface.mdnsQueueNameToResolve(ip)

	 interface.snmpGetBatch(ip, "public", "1.3.6.1.2.1.1.5.0", 0)

	 if(string.contains(manufacturer, "HP") or string.contains(manufacturer, "Hewlett Packard")) then
	    -- Query printer model
	    interface.snmpGetBatch(ip, "public", "1.3.6.1.2.1.25.3.2.1.3.1", 0)
	 end
      else
	 local ip_addr = mac
	 local mdns_services = ip

	 io.write("[MDNS Services] '"..ip_addr .. "' = '" ..mdns_services.."'\n")

	 if(string.contains(mdns_services, '_sftp')) then
	    osx_devices[ip_addr] = 1
	 end

	 ntop.resolveName(ip) -- Force address resolution
      end
   end

   io.write("Analyzing SSDP...\n")
   ssdp = analyzeSSDP(ssdp)

   local show_services = false

   io.write("Collecting MDNS responses\n")
   local mdns = interface.mdnsReadQueuedResponses()
   for ip,rsp in pairsByValues(mdns, asc) do
      io.write("[MDNS Resolver] "..ip.." = "..rsp.."\n")
   end

   for ip,_ in pairs(osx_devices) do
      io.write("[MDNS OSX] Querying "..ip.. "\n")
      interface.mdnsQueueAnyQuery(ip, "_sftp-ssh._tcp.local")
   end

   io.write("Collecting SNMP responses\n")
   local snmp = interface.snmpReadResponses()
   for ip,rsp in pairsByValues(snmp, asc) do
      io.write("[SNMP] "..ip.." = "..rsp.."\n")
   end

   io.write("Collecting MDNS OSX responses\n")
   osx_devices = interface.mdnsReadQueuedResponses()
   io.write("Collected MDNS OSX responses\n")

   for a,b in pairs(osx_devices) do
      io.write("[MDNS OSX] "..a.." / ".. b.. "\n")
   end


   -- Time to pack the results in a table...
   local status = discoverStatus("OK")
   local res = {}

   for mac, ip in pairsByValues(arp_mdns, asc) do
      if((string.find(mac, ":") == nil)
	 or (ip == "0.0.0.0")
	 or (ip == "255.255.255.255")) then
	 goto continue
      end

      local entry = {ip = ip, mac = mac, ghost = false, information = {}}

      local host = interface.getHostInfo(ip, 0) -- no VLAN
      local sym, device_type, device_label
      local manufacturer
      local services = ""
      local symIP = mdns[ip]

      if(host ~= nil) then sym = host["name"] else sym = ntop.resolveName(ip) end
      if not isEmptyString(sym) and sym ~= ip then
	 entry["sym"] = sym
      end
      if not isEmptyString(symIP) and symIP ~= ip then
	 entry["symIP"] = symIP
      end

      if not isEmptyString(arp_mdns[ip]) then
	 entry["information"] = table.merge(entry["information"], string.split(arp_mdns[ip], ";"))
      end

      if ssdp[ip] then
	 if ssdp[ip].icon then entry["icon"] = ssdp[ip].icon end
	 if ssdp[ip].manufacturer then manufacturer = ssdp[ip].manufacturer end
	 if ssdp[ip].modelName then entry["modelName"] = ssdp[ip].modelName end
	 if ssdp[ip].url then entry["url"] = ssdp[ip].url end
	 if ssdp[ip].services then
	    entry["information"] = table.merge(entry["information"], ssdp[ip].services)
	    for i, name in ipairs(ssdp[ip].services) do services = services .. ";" .. name end
	 end
      end
      if isEmptyString(manufacturer) then manufacturer = get_manufacturer_mac(mac) end
      entry["manufacturer"] = manufacturer

      if(ghost_macs[mac] ~= nil) then entry["ghost"] = true  end

      device_type, device_label = findDevice(ip, mac, manufacturer, arp_mdns[ip], services, ssdp[ip], mdns, snmp[ip], osx_devices[ip], sym)

      if isEmptyString(device_label) then
	 local mac_info = interface.getMacInfo(mac, 0) -- 0 = VLAN
	 device_label = device_label .. discover.devtype2icon(mac_info.devtype)
      end
      interface.setMacDeviceType(mac, discover.devtype2id(device_type), false) -- false means don't overwrite if already set to ~= unknown

      entry["device_type"] = device_type
      entry["device_label"] = device_label

      res[#res + 1] = entry
      ::continue::
   end

   return {status = status, devices = res, ghost_found = ghost_found}
end

-- #############################################################################

print("<p>&nbsp;<H2>"..ifname.." "..i18n("discover.network_discovery").."</H2><p>&nbsp;<p>\n")

local discovered = discover2table(ifname)

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


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
