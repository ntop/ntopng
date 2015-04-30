
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

http_hosts = interface.listHTTPhosts()




local host_t = nil


host_PROVA = nil
for k,v in pairsByKeys(http_hosts, asc) do

   print (k .."|".. v["host"] .."|".. v["http_requests"] .."<br>")



end
