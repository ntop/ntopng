--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

local function getbaseURL(url)
   local name = url:match( "([^/]+)$" )

   if((name == "") or (name == nil)) then
      return(url)
   else
      return(string.sub(url, 1, string.len(url)-string.len(name)-1))
   end
end

interface.select(ifname)
res = interface.scanHosts()

print("<table>\n")
for mac,ip in pairsByValues(res, asc) do
   print("<tr><th>"..ip.."</th><td>"..mac.."</td></tr>\n")
end
print("</table>\n")

res = interface.discoverHosts(5)


print("<table>\n")


for url,host in pairs(res) do
   local rsp = ntop.httpGet(url, "", "", 3 --[[ seconds ]])
   local friendlyName = ""
   local manufacturer = ""
   local icon = ""
   local base_url = getbaseURL(url)
   
   if(rsp ~= nil) then
      local xml = require("xmlSimple").newParser()
      local r = xml:ParseXmlText(rsp["CONTENT"])
      
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
	 end
      end

      if(r.root ~= nil) then
	 if(r.root.device ~= nil) then
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

      -- io.write(rsp["CONTENT"].."\n")
   end
      
   print("<tr><td>"..host.."</td><td>".. icon .."</td><td>".. manufacturer .."</td><th align=left><A HREF="..url..">"..friendlyName.."</A></td></tr>\n")
end

print("</table>\n")
