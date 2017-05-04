--
-- (C) 2014-15-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

host_ip = _GET["host"]

interface.select(ifname)
host = interface.getHostInfo(host_ip)

if(host == nil) then
   value = 0
else
   value = host["packets.sent"]+host["packets.rcvd"]
end

print(' { "value": ' .. value .. ' } ')