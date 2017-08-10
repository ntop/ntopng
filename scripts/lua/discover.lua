--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"


sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local apple_osx_versions = {
   ['4'] = 'Mac OS X 10.0 (Cheetah)',
   ['5'] = 'Mac OS X 10.1 (Puma)',
   ['6'] = 'Mac OS X 10.2 (Jaguar)',
   ['7'] = 'Mac OS X 10.3 (Panther)',
   ['8'] = 'Mac OS X 10.4 (Tiger)',
   ['9'] = 'Mac OS X 10.5 (Leopard)',
   ['10'] = 'Mac OS X 10.6 (Snow Leopard)',
   ['11'] = 'Mac OS X 10.7 (Lion)',
   ['12'] = 'OS X 10.8 (Mountain Lion)',
   ['13'] = 'OS X 10.9 (Mavericks)',
   ['14'] = 'OS X 10.10 (Yosemite)',
   ['15'] = 'OS X 10.11 (El Capitan)',
   ['16'] = 'OS X 10.12 (Sierra)',
}

local apple_products = {
   ['Macmini5,3'] = 'Mac mini "Core i7" 2.0 (Mid-2011/Server)',
   ['Macmini5,2'] = 'Mac mini "Core i7" 2.7 (Mid-2011)',
   ['Macmini5,1'] = 'Mac mini "Core i5" 2.3 (Mid-2011)',
   ['MacPro4,1'] = 'Mac Pro "Eight Core" 2.93 (2009/Nehalem)',
   ['iMac16,2'] = 'iMac "Core i7" 3.3 21.5-Inch (4K, Late 2015)',
   ['iMac16,1'] = 'iMac "Core i5" 1.6 21.5-Inch (Late 2015)',
   ['iMac5,1'] = 'iMac "Core 2 Duo" 2.33 20-Inch',
   ['MacBookPro7,1'] = 'MacBook Pro "Core 2 Duo" 2.66 13" Mid-2010',
   ['MacPro2,1'] = 'Mac Pro "Eight Core" 3.0 (2,1)',
   ['MacBook10,1'] = 'MacBook "Core i7" 1.4 12" (Mid-2017)',
   ['Macmini1,1'] = 'Mac mini "Core Duo" 1.83',
   ['iMac12,2'] = 'iMac "Core i7" 3.4 27-Inch (Mid-2011)',
   ['iMac6,1'] = 'iMac "Core 2 Duo" 2.33 24-Inch',
   ['MacBookPro5,1'] = 'MacBook Pro "Core 2 Duo" 2.93 15" (Unibody)',
   ['MacBookPro11,5'] = 'MacBook Pro "Core i7" 2.8 15" Mid-2015 (DG)',
   ['MacBookPro11,4'] = 'MacBook Pro "Core i7" 2.8 15" Mid-2015 (IG)',
   ['MacBookPro11,3'] = 'MacBook Pro "Core i7" 2.8 15" Mid-2014 (DG)',
   ['MacBookPro11,2'] = 'MacBook Pro "Core i7" 2.8 15" Mid-2014 (IG)',
   ['MacBookPro11,1'] = 'MacBook Pro "Core i7" 3.0 13" Mid-2014',
   ['MacBookPro10,2'] = 'MacBook Pro "Core i7" 3.0 13" Early 2013',
   ['MacBookPro10,1'] = 'MacBook Pro "Core i7" 2.8 15" Early 2013',
   ['MacBookPro5,5'] = 'MacBook Pro "Core 2 Duo" 2.53 13" (SD/FW)',
   ['MacBookAir7,1'] = 'MacBook Air "Core i7" 2.2 11" (Early 2015)',
   ['MacBookAir7,2'] = 'MacBook Air "Core i7" 2.2 13" (Early 2015)',
   ['iMac17,1'] = 'iMac "Core i7" 4.0 27-Inch (5K, Late 2015)',
   ['MacBookPro8,1'] = 'MacBook Pro "Core i7" 2.8 13" Late 2011',
   ['MacBookPro8,2'] = 'MacBook Pro "Core i7" 2.5 15" Late 2011',
   ['MacBookPro8,3'] = 'MacBook Pro "Core i7" 2.5 17" Late 2011',
   ['MacBook6,1'] = 'MacBook "Core 2 Duo" 2.26 13" (Uni/Late 09)',
   ['MacBookPro4,1'] = 'MacBook Pro "Core 2 Duo" 2.6 17" (08)',
   ['Macmini4,1'] = 'Mac mini "Core 2 Duo" 2.66 (Server)',
   ['PowerMac10,2'] = 'Mac mini G4/1.5',
   ['PowerMac10,1'] = 'Mac mini G4/1.42',
   ['iMac13,2'] = 'iMac "Core i7" 3.4 27-Inch (Late 2012)',
   ['iMac13,1'] = 'iMac "Core i3" 3.3 21.5-Inch (Early 2013)',
   ['iMac9,1'] = 'iMac "Core 2 Duo" 2.26 20-Inch (Mid-2009)',
   ['Macmini3,1'] = 'Mac mini "Core 2 Duo" 2.53 (Server)',
   ['iMac5,2'] = 'iMac "Core 2 Duo" 1.83 17-Inch (IG)',
   ['MacBook2,1'] = 'MacBook "Core 2 Duo" 2.16 13" (Black)',
   ['MacBook1,1'] = 'MacBook "Core Duo" 2.0 13" (Black)',
   ['iMac14,4'] = 'iMac "Core i5" 1.4 21.5-Inch (Mid-2014)',
   ['iMac14,1'] = 'iMac "Core i5" 2.7 21.5-Inch (Late 2013)',
   ['iMac14,3'] = 'iMac "Core i7" 3.1 21.5-Inch (Late 2013)',
   ['iMac14,2'] = 'iMac "Core i7" 3.5 27-Inch (Late 2013)',
   ['MacBookPro2,2'] = 'MacBook Pro "Core 2 Duo" 2.33 15"',
   ['MacBookAir3,2'] = 'MacBook Air "Core 2 Duo" 2.13 13" (Late 2010)',
   ['MacBookPro13,1'] = 'MacBook Pro "Core i7" 2.4 13" Late 2016',
   ['MacBookPro13,3'] = 'MacBook Pro "Core i7" 2.9 15" Touch/Late 2016',
   ['MacBookPro13,2'] = 'MacBook Pro "Core i7" 3.3 13" Touch/Late 2016',
   ['MacBook9,1'] = 'MacBook "Core m7" 1.3 12" (Early 2016)',
   ['MacBookAir6,1'] = 'MacBook Air "Core i7" 1.7 11" (Early 2014)',
   ['MacBookAir6,2'] = 'MacBook Air "Core i7" 1.7 13" (Early 2014)',
   ['MacBookPro9,1'] = 'MacBook Pro "Core i7" 2.7 15" Mid-2012',
   ['MacBookPro9,2'] = 'MacBook Pro "Core i7" 2.9 13" Mid-2012',
   ['MacBook3,1'] = 'MacBook "Core 2 Duo" 2.2 13" (Black-SR)',
   ['MacPro6,1'] = 'Mac Pro "Twelve Core" 2.7 (Late 2013)',
   ['iMac10,1'] = 'iMac "Core 2 Duo" 3.33 27-Inch (Late 2009)',
   ['MacBookPro1,1'] = 'MacBook Pro "Core Duo" 2.16 15"',
   ['MacBookPro5,3'] = 'MacBook Pro "Core 2 Duo" 3.06 15" (SD)',
   ['MacBookPro5,2'] = 'MacBook Pro "Core 2 Duo" 3.06 17" Mid-2009',
   ['iMac8,1'] = 'iMac "Core 2 Duo" 3.06 24-Inch (Early 2008)',
   ['MacBookPro5,4'] = 'MacBook Pro "Core 2 Duo" 2.53 15" (SD)',
   ['Macmini2,1'] = 'Mac mini "Core 2 Duo" 2.0',
   ['MacBookAir3,1'] = 'MacBook Air "Core 2 Duo" 1.6 11" (Late 2010)',
   ['Macmini6,1'] = 'Mac mini "Core i5" 2.5 (Late 2012)',
   ['MacBookPro1,2'] = 'MacBook Pro "Core Duo" 2.16 17"',
   ['iMac4,1'] = 'iMac "Core Duo" 2.0 20-Inch',
   ['iMac4,2'] = 'iMac "Core Duo" 1.83 17-Inch (IG)',
   ['Macmini7,1'] = 'Mac mini "Core i7" 3.0 (Late 2014)',
   ['MacBookPro2,1'] = 'MacBook Pro "Core 2 Duo" 2.33 17"',
   ['MacBook5,1'] = 'MacBook "Core 2 Duo" 2.4 13" (Unibody)',
   ['MacBook5,2'] = 'MacBook "Core 2 Duo" 2.13 13" (White-09)',
   ['MacBookPro14,2'] = 'MacBook Pro "Core i7" 3.5 13" Touch/Mid-2017',
   ['MacBookPro14,3'] = 'MacBook Pro "Core i7" 3.1 15" Touch/Mid-2017',
   ['MacPro1,1*'] = 'Mac Pro "Quad Core" 3.0 (Original)',
   ['MacBookPro14,1'] = 'MacBook Pro "Core i7" 2.5 13" Mid-2017',
   ['MacBookPro12,1'] = 'MacBook Pro "Core i7" 3.1 13" Early 2015',
   ['MacBook8,1'] = 'MacBook "Core M" 1.3 12" (Early 2015)',
   ['iMac15,1'] = 'iMac "Core i5" 3.3 27-Inch (5K, Mid-2015)',
   ['MacBookAir1,1'] = 'MacBook Air "Core 2 Duo" 1.8 13" (Original)',
   ['MacBookAir2,1'] = 'MacBook Air "Core 2 Duo" 2.13 13" (Mid-09)',
   ['iMac7,1'] = 'iMac "Core 2 Extreme" 2.8 24-Inch (Al)',
   ['MacBookAir5,2'] = 'MacBook Air "Core i7" 2.0 13" (Mid-2012)',
   ['MacBook4,1'] = 'MacBook "Core 2 Duo" 2.4 13" (Black-08)',
   ['MacBookAir5,1'] = 'MacBook Air "Core i7" 2.0 11" (Mid-2012)',
   ['MacBookPro3,1'] = 'MacBook Pro "Core 2 Duo" 2.6 17" (SR)',
   ['iMac11,1'] = 'iMac "Core i7" 2.8 27-Inch (Late 2009)',
   ['iMac11,2'] = 'iMac "Core i5" 3.6 21.5-Inch (Mid-2010)',
   ['iMac11,3'] = 'iMac "Core i7" 2.93 27-Inch (Mid-2010)',
   ['MacBook7,1'] = 'MacBook "Core 2 Duo" 2.4 13" (Mid-2010)',
   ['Macmini6,2'] = 'Mac mini "Core i7" 2.6 (Late 2012/Server)',
   ['MacPro5,1'] = 'Mac Pro "Twelve Core" 3.06 (Server 2012)',
   ['MacBookPro6,2'] = 'MacBook Pro "Core i7" 2.8 15" Mid-2010',
   ['MacBookPro6,1'] = 'MacBook Pro "Core i7" 2.8 17" Mid-2010',
   ['iMac18,1'] = 'iMac "Core i5" 2.3 21.5-Inch (Mid-2017)',
   ['iMac18,3'] = 'iMac "Core i7" 4.2 27-Inch (5K, Mid-2017)',
   ['iMac18,2'] = 'iMac "Core i7" 3.6 21.5-Inch (4K, Mid-2017)',
   ['iMac12,1'] = 'iMac "Core i3" 3.1 21.5-Inch (Late 2011)',
   ['MacBookAir4,2'] = 'MacBook Air "Core i5" 1.6 13" (Edu Only)',
   ['MacBookAir4,1'] = 'MacBook Air "Core i7" 1.8 11" (Mid-2011)',
   ['MacPro3,1'] = 'Mac Pro "Eight Core" 3.2 (2008)'
}

local function getbaseURL(url)
   local name = url:match( "([^/]+)$" )

   if((name == "") or (name == nil)) then
      return(url)
   else
      return(string.sub(url, 1, string.len(url)-string.len(name)-1))
   end
end

local function findDevice(ip, mac, manufacturer, _mdns, _ssdp, names, snmp, osx)
   local mdns = { }
   local ssdp = { }
   local str

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

   if(_ssdp ~= nil) then
      --io.write(mac .. " /" .. manufacturer .. " / ".. _ssdp.."\n")

      local ssdp_items = string.split(_ssdp, ";")

      if(ssdp_items == nil) then
	 ssdp[_ssdp] = 1
      else
	 for _,v in pairs(ssdp_items) do
	    ssdp[v] = 1
	 end
      end
   end   


   if(osx ~= nil) then
      -- model=iMac11,3;osxvers=16
      local elems   = string.split(osx, ';')

      if(#elems == 2) then
	 local model   = string.split(elems[1], '=')
	 local osxvers = string.split(elems[2], '=')

	 if(apple_products[model[2]] ~= nil) then
	    model = apple_products[model[2]]
	 else
	    model = model[2]
	 end

	 if(apple_osx_versions[osxvers[2]] ~= nil) then
	    osxvers = apple_osx_versions[osxvers[2]]
	 else
	    osxvers = osxvers[2]
	 end

	 osx = "<br>"..model.."<br>"..osxvers
      end
   end
   
   if(mdns["_ssh._tcp.local"] ~= nil) then
      local ret = '</i> <i class="fa fa-desktop fa-lg" aria-hidden="true"></i> (Apple)'

      if(osx ~= nil) then ret = ret .. osx end
      return(ret)
   elseif(mdns["_nvstream_dbd._tcp.local"] ~= nil) then
      return('<i class="fa fa-desktop fa-lg" aria-hidden="true"></i> (Windows)')
   end

   if((ssdp["upnp-org:serviceId:AVTransport"] ~= nil) or (ssdp["urn:upnp-org:serviceId:RenderingControl"] ~= nil)) then
      return('<i class="fa fa-television fa-lg" aria-hidden="true"></i>')
   end

   if(names[ip] == nil) then
      str = ""
   else
      str = string.lower(names[ip])
   end

   if(string.contains(manufacturer, "Oki Electric") and (snmp ~= nil)) then
      return('<i class="fa fa-print fa-lg" aria-hidden="true"></i> ('..snmp..')')
   elseif(string.contains(manufacturer, "Hikvision")) then
      return('<i class="fa fa-video-camera fa-lg" aria-hidden="true"></i>')
   elseif(string.contains(manufacturer, "Hewlett Packard")
	     and (snmp ~= nil)
	  and string.contains(snmp, "Jet")) then
      return('<i class="fa fa-print fa-lg" aria-hidden="true"></i> ('..snmp..')')
   elseif(string.contains(manufacturer, "Apple, Inc.")) then
      if(string.contains(str, "iphone")) then
	 return('<i class="fa fa-mobile fa-lg" aria-hidden="true"></i> (iPhone)')
      elseif(string.contains(str, "ipad")) then
	 return('<i class="fa fa-tablet fa-lg" aria-hidden="true"></i> (iPad)')
      elseif(string.contains(str, "ipod")) then
	 return('<i class="fa fa-mobile fa-lg" aria-hidden="true"></i> (iPod)')
      else
	 return('</i> <i class="fa fa-desktop fa-lg" aria-hidden="true"></i> (Apple)')
      end
   end
   
   if(string.contains(mac, "F0:4F:7C") and string.contains(str, "kindle-")) then
      return('<i class="fa fa-tablet fa-lg" aria-hidden="true"></i> (Kindle)')
   end

   -- io.write(ip .. " / " .. names["gateway.local"].."\n")
   if(names["gateway.local"] == ip) then
      return('<i class="fa fa-arrows fa-lg" aria-hidden="true"></i>')
   end

   if(snmp ~= nil) then
      if(string.contains(snmp, "router")) then
	 return('<i class="fa fa-arrows fa-lg" aria-hidden="true"></i> ('..snmp..')')
      elseif(string.contains(snmp, "air")) then
	 return('<i class="fa fa-wifi fa-lg" aria-hidden="true"></i> ('..snmp..')')
      else
	 return(snmp)
      end
   end

   return("")
end


-- #############################################################################

local function analyzeSSDP(ssdp)
   local rsp = {}

   for url,host in pairs(ssdp) do
      local hresp = ntop.httpGet(url, "", "", 3 --[[ seconds ]])
      local friendlyName = ""
      local manufacturer = ""
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
	 rsp[host] = { ["icon"] = icon, ["manufacturer"] = manufacturer, ["url"] = "<A HREF="..url..">"..friendlyName.."</A>", ["services"] = services }
      end

      -- io.write(rsp[host].icon .. " / " ..rsp[host].manufacturer .. " / " ..rsp[host].url .. " / " .. "\n")
   end

   return(rsp)
end



interface.select(ifname)

io.write("Starting ARP discovery...\n")
local arp_mdns = interface.scanHosts()
io.write("Starting SSDP discovery...\n")
local ssdp = interface.discoverHosts(3)

local osx_devices = { }
for mac,ip in pairsByValues(arp_mdns, asc) do
   -- io.write("## '"..mac .. "' = '" ..ip.."'\n")

   if(string.find(mac, ":") ~= nil) then
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
   -- io.write("[SNMP] "..ip.." = "..rsp.."\n")
end


io.write("Collecting MDNS OSX responses\n")
osx_devices = interface.mdnsReadQueuedResponses()
io.write("Collected MDNS OSX responses\n")

for a,b in pairs(osx_devices) do
   io.write("[MDNS OSX] "..a.." / ".. b.. "\n")
end


for mac,ip in pairsByValues(arp_mdns, asc) do
   if(string.find(mac, ":") ~= nil) then
      -- This is an ARP entry
      local deviceType
      local symIP = mdns[ip]
      local services = ""
      local sym = ntop.resolveName(ip)
      
      print("<tr><td align=left>")

      print("<a href=" .. ntop.getHttpPrefix().. "/lua/host_details.lua?host="..ip..">"..ip.."</A>")
      if(ssdp[ip] and ssdp[ip].icon) then print(ssdp[ip].icon .. "&nbsp;") end

      print("</td><td>"..sym)
      
      if(symIP ~= nil) then
	 if(sym ~= "") then
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

      print(manufacturer .. "</td><td><A HREF="..ntop.getHttpPrefix().. "/lua/mac_details.lua?host="..mac..">"..mac.."</A>")

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

      deviceType = findDevice(ip, mac, manufacturer, arp_mdns[ip], services, mdns, snmp[ip], osx_devices[ip])
      if(deviceType == "") then deviceType = "&nbsp;" end

      print("</td><td>"..deviceType.."</td></tr>\n")
   end
end

print("</table>\n")

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
