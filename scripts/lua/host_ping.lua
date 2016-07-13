--
--(C)2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

interface.select(ifname)
host_info = url2hostinfo(_GET)

pingTime = interface.pingHost(host_info["host"], host_info["vlan"])
if(pingTime and pingTime > 0) then print(pingTime) else print(0) end
