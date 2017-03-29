--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"
require "historical_utils"
sendHTTPHeader('text/html; charset=iso-8859-1')

interface.select(ifname)
host_info = url2hostinfo(_GET)

stats = interface.getHostInfo(host_info["host"], host_info["vlan"])


if(stats ~= nil) then
   local icmp = stats["ICMP"]   
   local tot = 0

   for key, value in pairs(icmp) do
      print('<tr><th>'..key..'</th><td align=right>'..formatPackets(value.sent).. '</td><td align=right>'..formatPackets(value.rcvd)..'</td><td>')
      breakdownBar(value.sent, "Sent", value.rcvd, "Rcvd", 0, 100)      
      print("</td><td align=right>".. formatPackets(value.sent+value.rcvd) .."</td></tr>\n")
   end   
end
