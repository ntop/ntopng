--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"


sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")


local function getbaseURL(url)
   local name = url:match( "([^/]+)$" )

   if((name == "") or (name == nil)) then
      return(url)
   else
      return(string.sub(url, 1, string.len(url)-string.len(name)-1))
   end
end

local function findDevice(ip, mac, manufacturer, _mdns, _ssdp, names)
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
   
   if(mdns["_afpovertcp._tcp.local"] ~= nil) then
      return('</i> <i class="fa fa-desktop fa-lg" aria-hidden="true"></i> (Apple)')
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
      
   if(manufacturer == "Apple, Inc.") then
      if(string.contains(str, "iphone")) then
	 return('<i class="fa fa-mobile fa-lg" aria-hidden="true"></i> (iPhone)')
      elseif(string.contains(str, "ipad")) then
	 return('<i class="fa fa-tablet fa-lg" aria-hidden="true"></i> (iPad)')
      elseif(string.contains(str, "ipod")) then
	 return('<i class="fa fa-mobile fa-lg" aria-hidden="true"></i> (iPod)')
      else
	 return('<i class="fa fa-mobile fa-lg" aria-hidden="true"></i> (Apple)')
      end
   end

   if(string.contains(mac, "F0:4F:7C") and string.contains(str, "kindle-")) then
      return('<i class="fa fa-tablet fa-lg" aria-hidden="true"></i> (Kindle)')
   end

   -- io.write(ip .. " / " .. names["gateway.local"].."\n")
   if(names["gateway.local"] == ip) then
      return('<i class="fa fa-arrows fa-lg" aria-hidden="true"></i>')
   end
   
   if(string.contains(manufacturer, "Ubiquity") ~= nil) then
      rsp = ntop.snmpget(ip, "public", "1.3.6.1.2.1.1.5.0", 2, 0)
      if(rsp ~= nil) then
	 for k, v in pairs(rsp) do

	    if(string.contains(v, "router")) then
	       return('<i class="fa fa-arrows fa-lg" aria-hidden="true"></i> ('..v..')')
	    elseif(string.contains(v, "air")) then
	       return('<i class="fa fa-wifi fa-lg" aria-hidden="true"></i> ('..v..')')
	    else
	       return(v)
	    end
	 end
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

local arp_mdns = interface.scanHosts()
local ssdp = interface.discoverHosts(3)

for mac,ip in pairsByValues(arp_mdns, asc) do
   -- io.write("## '"..mac .. "' = '" ..ip.."'\n")
   
   if(string.find(mac, ":") ~= nil) then
      -- This is an ARP entry
      -- io.write("Attempting to resolve "..ip.."\n")
      interface.mdnsQueueNameToResolve(ip)
   end
end

ssdp = analyzeSSDP(ssdp)

print("<table class=\"table table-bordered table-striped\">\n<tr><th>IP Address</th><th>MAC</th><th>Services</th><th>Information</th><th>Device</th></tr>")

local mdns = interface.mdnsReadQueuedResponses()

for mac,ip in pairsByValues(arp_mdns, asc) do
   if(string.find(mac, ":") ~= nil) then
      -- This is an ARP entry
      local deviceType
      local symIP = mdns[ip]
      local services = ""
      
      print("<tr><th align=left>")
      
      print("<a href=" .. ntop.getHttpPrefix().. "/lua/host_details.lua?host="..ip..">"..ip.."</A>")
      if(ssdp[ip] and ssdp[ip].icon) then print(ssdp[ip].icon .. "&nbsp;") end
      
      if(symIP ~= nil) then print(" [".. symIP .."]") end
      print("</th>")
      
      print("<td align=left>")
      if(ssdp[ip] and ssdp[ip].manufacturer) then
	 manufacturer = ssdp[ip].manufacturer
	 print(ssdp[ip].manufacturer .. " ( <A HREF="..ntop.getHttpPrefix().. "/lua/mac_details.lua?host="..mac..">"..mac.."</A> )")
      else
	 manufacturer = get_manufacturer_mac(mac)
	 print(get_symbolic_mac(mac))
      end
      print("</td><td>")
		      
      if(ssdp[ip] ~= nil) then      
	 if(ssdp[ip].services ~= nil) then
	    for i, name in ipairs(ssdp[ip].services) do
	       if(i > 1) then print("<br>") end
	       print(name)
	       services = services .. ";" .. name
	    end
	 end
	 
	 if(arp_mdns[ip] ~= nil) then
	    print(arp_mdns[ip])
	 end
	 
	 print("</td><td>")
	 
	 if(ssdp[ip].url) then print(ssdp[ip].url .. "&nbsp;") end
      else
	 print("&nbsp;</td><td>&nbsp;")
      end

      deviceType = findDevice(ip, mac, manufacturer, arp_mdns[ip], services, mdns)

      print("</td><td>"..deviceType.."</td></tr>\n")
   end
end

print("</table>\n")
