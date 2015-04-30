--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"

host_info = url2hostinfo(_GET)

sendHTTPHeader('application/json')

interface.select(ifname)

if((_GET["aggregated"] == nil) or (_GET["aggregated"] == 0)) then
   aggregation = false
else
   aggregation = true
end


rsp = interface.getHostActivityMap(host_info["host"], aggregation, host_info["vlan"])

print(rsp)