--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"

host_info = url2hostinfo(_GET)

sendHTTPHeader('application/json')

interface.select(ifname)

rsp = interface.getHostActivityMap(host_info["host"], host_info["vlan"])

print(rsp)