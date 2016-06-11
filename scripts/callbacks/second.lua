--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if (ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
end

require "lua_utils"
require "graph_utils"

-- Toggle debug
local enable_second_debug = 0

ifnames = interface.getIfNames()

for _,ifname in pairs(ifnames) do
   a = string.ends(ifname, ".pcap")
   if(not(a)) then
      interface.select(ifname)
      ifstats = aggregateInterfaceStats(interface.getStats())

      dirs = ntop.getDirs()
      basedir = fixPath(dirs.workingdir .. "/" .. ifstats.id .. "/rrd")

      --io.write(basedir.."\n")
      if(not(ntop.exists(basedir))) then
	 if(enable_second_debug == 1) then io.write('Creating base directory ', basedir, '\n') end
	 ntop.mkdir(basedir)
      end

      interface.setSecondTraffic()

      -- Traffic stats
      makeRRD(basedir, ifname, "bytes", 1, ifstats.bytes)
      makeRRD(basedir, ifname, "packets", 1, ifstats.packets)
      makeRRD(basedir, ifname, "drops", 1, ifstats.drops)

      -- General stats
      makeRRD(basedir, ifname, "num_hosts", 1, ifstats.hosts)
      makeRRD(basedir, ifname, "num_flows", 1, ifstats.flows)
      makeRRD(basedir, ifname, "num_http_hosts", 1, ifstats.http_hosts)

      -- TCP stats
      makeRRD(basedir, ifname, "tcp_retransmissions", 1, ifstats.tcpPacketStats.retransmissions)
      makeRRD(basedir, ifname, "tcp_ooo", 1, ifstats.tcpPacketStats.out_of_order)
      makeRRD(basedir, ifname, "tcp_lost", 1, ifstats.tcpPacketStats.lost)
   end
end -- for _,ifname in pairs(ifnames) do
