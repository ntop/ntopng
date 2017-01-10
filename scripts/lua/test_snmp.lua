--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")


community = _GET["community"]
host      = _GET["host"]


print('Host: '..host.."<p>\n")
print('Community: '..community.."<p>\n")

print('<table class="table table-bordered table-striped">\n')

sysname    = "1.3.6.1.2.1.1.1.0"
syscontact = "1.3.6.1.2.1.1.4.0"

rsp = ntop.snmpget(host, community, sysname, syscontact)
if (rsp ~= nil) then
   for k, v in pairs(rsp) do
      print('<tr><th width=35%>'..k..'</th><td colspan=2>'.. v..'</td></tr>\n')
   end
end

rsp = ntop.snmpgetnext(host, community, syscontact)
if (rsp ~= nil) then
   for k, v in pairs(rsp) do
      print('<tr><th width=35%>'..k..'</th><td colspan=2>'.. v..'</td></tr>\n')
   end
end

print('</table>\n')


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
