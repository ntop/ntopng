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

local arp = interface.scanHosts()
local ssdp = interface.discoverHosts(3)

for mac,ip in pairsByValues(arp, asc) do
   -- io.write("Attempting to resolve "..ip.."\n")
   interface.mdnsQueueNameToResolve(ip)
end

ssdp = analyzeSSDP(ssdp)

print("<table class=\"table table-bordered table-striped\">\n<tr><th>IP Address</th><th>MAC</th><th>Services</th><th>Information</th></tr>")

local mdns = interface.mdnsReadQueuedResponses()

for mac,ip in pairsByValues(arp, asc) do
   local symIP = mdns[ip]
   print("<tr><th align=left>")

   print("<a href=" .. ntop.getHttpPrefix().. "/lua/host_details.lua?host="..ip..">"..ip.."</A>")
   if(ssdp[ip] and ssdp[ip].icon) then print(ssdp[ip].icon .. "&nbsp;") end

   if(symIP ~= nil) then print(" [".. symIP .."]") end
   print("</th>")

   print("<td align=left>")
   if(ssdp[ip] and ssdp[ip].manufacturer) then
      print(ssdp[ip].manufacturer .. " ( <A HREF="..ntop.getHttpPrefix().. "/lua/mac_details.lua?host="..mac..">"..mac.."</A> )")
   else
      print(get_symbolic_mac(mac))
   end
   print("</td><td>")

   if(ssdp[ip] ~= nil) then      
      if(ssdp[ip].services ~= nil) then
	 for i, name in ipairs(ssdp[ip].services) do
	    if(i > 1) then print("<br>") end
	    print(name)
	 end
      else
	 print("Empty&nbsp;")
      end

      print("</td><td>")
      
      if(ssdp[ip].url) then print(ssdp[ip].url .. "&nbsp;") end
   else
      print("&nbsp;</td><td>&nbsp;")
   end

   print("</td></tr>\n")
end

print("</table>\n")
