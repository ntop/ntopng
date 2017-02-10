--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "about"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

info = ntop.getInfo()
print("<hr /><h2>"..info["product"].." Runtime Status</h2>")

print("<table class=\"table table-bordered table-striped\">\n")
if(info["pro.systemid"] and (info["pro.systemid"] ~= "")) then
  print("<tr><th nowrap>System Id</th><td>".. info["pro.systemid"].."</td></tr>\n")
end

vers = string.split(info["version.git"], ":")
if((vers ~= nil) and (vers[2] ~= nil)) then
   ntopng_git_url = "<A HREF=\"https://github.com/ntop/ntopng/commit/".. vers[2] .."\">"..info["version"].."</A>"
else
   ntopng_git_url = info["version"]
end

print("<tr><th nowrap>Version</th><td>"..ntopng_git_url)

if(info["pro.release"] == false) then
   print(" - Community")
else
   print(" - Pro Small Business")
end

if(info["version.embedded_edition"] == true) then
   print("/Embedded")
end

print(" Edition</td></tr>\n")

print("<tr><th nowrap>Platform</th><td>"..info["platform"].." - "..info["bits"] .." bit</td></tr>\n")
print("<tr><th nowrap>Startup Line</th><td>ntopng "..info["command_line"].."</td></tr>\n")
print("<tr><th nowrap>Last Log Trace</th><td><code>\n")

for i=1,32 do
    msg = ntop.listIndexCache("ntopng.trace", i)
    if(msg ~= nil) then
        print(msg.."<br>\n")	
    end			
end

print("</code></td></tr>\n")


print("</table>\n")


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
