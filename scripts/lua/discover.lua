--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
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

local function findDevice(ip, mac, manufacturer, _mdns, ssdp_str, ssdp_entries, names, snmp, osx)
   local mdns = { }
   local ssdp = { }
   local str
   local friendlyName = ""

   if(ssdp_entries and ssdp_entries.friendlyName) then
      friendlyName = ssdp_entries["friendlyName"]
   end
   
   if((names == nil) or (names[ip] == nil)) then
      hostname = ""
   else
      hostname = string.lower(names[ip])
   end
   
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

      ret = '</i>'..discover.asset_icons[icon]..' (Apple)'

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
   elseif(string.contains(manufacturer, "HUAWEI")) then
      return 'phone', discover.asset_icons['phone']
   elseif(string.contains(manufacturer, 'TP%-LINK')) then -- % is the escape char in Lua
      return 'wifi', discover.asset_icons['wifi']
   elseif(string.contains(manufacturer, 'Broadband')) then -- % is the escape char in Lua
      return 'networking', discover.asset_icons['networking']
   elseif(string.contains(manufacturer, "Samsung Electronics")) then
      return 'phone', discover.asset_icons['phone']
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
      if(string.contains(hostname, "iphone")) then
	 return 'phone', discover.asset_icons['phone']..' (iPhone)'
      elseif(string.contains(hostname, "ipad")) then
	 return 'tablet', discover.asset_icons['tablet']..' (iPad)'
      elseif(string.contains(hostname, "ipod")) then
	 return 'phone', discover.asset_icons['phone']..' (iPod)'
      else
	 local ret = '</i> '..discover.asset_icons['workstation']..' (Apple)'
	 local sym = names[ip]
	 local what = 'workstation'
	 
	 if(sym == nil) then sym = "" else sym = string.lower(sym) end
	 
	 if((snmp and string.contains(snmp, "capsule"))
	       or string.contains(sym, "capsule"))
	 then
	    ret = '</i> '..discover.asset_icons['nas']
	    what = 'nas'
	 elseif(string.contains(sym, "book")) then
	    ret = '</i> '..discover.asset_icons['laptop']..' (Apple)'
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

   if(string.starts(hostname, "desktop-")) then
      return 'workstation', discover.asset_icons['workstation']..' (Windows)'
   elseif(string.contains(hostname, "thinkpad")) then
      return 'laptop', discover.asset_icons['laptop']
   elseif(string.contains(hostname, "android")) then
      return 'phone', discover.asset_icons['phone']..' (Android)'
   elseif(string.contains(hostname, "%-NAS")) then
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

interface.select(ifname)

io.write("Starting ARP discovery...\n")
local arp_mdns = interface.arpScanHosts()

if(arp_mdns == nil) then
   -- Internal error
   print('<div class=\"alert alert-danger\"><i class="fa fa-warning fa-lg"></i> Unable to start network discovery</div>')
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
   return
end

local ghost_macs  = {}
local ghost_found = false

-- Add the known macs to the list
local known_macs = interface.getMacsInfo(nil, 999, 0, false, 0, tonumber(vlan), true, true, nil)

for _,hmac in pairs(known_macs.macs) do
   if(hmac["bytes.sent"] > 0) then -- Skip silent hosts
      if(arp_mdns[hmac.mac] == nil) then
	 local ips = interface.findHostByMac(hmac.mac)
	 -- io.write("Missing MAC "..hmac.mac.."\n")

	 for k,v in pairs(ips) do
	    arp_mdns[hmac.mac] = k
	    ghost_macs[hmac.mac] = k
	    ghost_found = true
	 end
      end
   end
end

io.write("Starting SSDP discovery...\n")
local ssdp = interface.discoverHosts(3)

local osx_devices = { }
for mac,ip in pairsByValues(arp_mdns, asc) do
   -- io.write("## '"..mac .. "' = '" ..ip.."'\n")

   if((ip == "0.0.0.0") or (ip == "255.255.255.255")) then
      -- This does not lokk like a good IP/MAC combination
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

print("<p>&nbsp;<H2>"..ifname.." Network Discovery</H2><p>&nbsp;<p>\n")
print("<table class=\"table table-bordered table-striped\">\n<tr><th>IP</th><th>Name</th><th>Manufacturer</th><th>MAC</th>")
if(show_services) then print("<th>Services</th>") end
print("<th>Information</th><th>Device</th></tr>")

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

for mac,ip in pairsByValues(arp_mdns, asc) do
   if((string.find(mac, ":") ~= nil)
	 and (ip ~= "0.0.0.0")
      	 and (ip ~= "255.255.255.255")) then
      -- This is an ARP entry
      local deviceType
      local symIP = mdns[ip]
      local services = ""
      local sym = ntop.resolveName(ip)
      
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

      print("</td><td>")

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
		  if(i > 1) then print("<br>") end
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

      deviceType,deviceLabel = findDevice(ip, mac, manufacturer, arp_mdns[ip], services, ssdp[ip], mdns, snmp[ip], osx_devices[ip])
      if(deviceLabel == "") then
	 local mac_info = interface.getMacInfo(mac, 0) -- 0 = VLAN
	 
	 deviceLabel = "&nbsp;"
	 discover.devtype2icon(mac_info.devtype)
      end
      print("</td><td>"..deviceLabel.."</td></tr>\n")
      interface.setMacDeviceType(mac, discover.devtype2id(deviceType), false) -- false means don't overwrite if already set to ~= unknown
   end
end

print("</table>\n")

if(ghost_found) then
   print('<b>NOTE</b>: The <font color=red>'..discover.ghost_icon..'</font> icon highlights ghost hosts (i.e. they do not belong to the interface IP address network).')
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
