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
enable_second_debug = false

if((_GET ~= nil) and (_GET["verbose"] ~= nil)) then
   enable_second_debug = true
end

if(enable_second_debug) then
   sendHTTPHeader('text/plain')
end

ifnames = interface.getIfNames()

for _,ifname in pairs(ifnames) do
   a = string.ends(ifname, ".pcap")
   if(not(a)) then
   if(enable_second_debug) then print("Processing "..ifname.."\n") end
      interface.select(ifname)
      ifstats = interface.getStats()
      -- tprint(ifstats)
      dirs = ntop.getDirs()
      basedir = fixPath(dirs.workingdir .. "/" .. ifstats.id .. "/rrd")

      --io.write(basedir.."\n")
      if(not(ntop.exists(basedir))) then
	 if(enable_second_debug) then io.write('Creating base directory ', basedir, '\n') end
	 ntop.mkdir(basedir)
      end

      interface.setSecondTraffic()

      -- Traffic stats
      makeRRD(basedir, ifname, "bytes", 1, ifstats.stats.bytes)
      makeRRD(basedir, ifname, "packets", 1, ifstats.stats.packets)
      makeRRD(basedir, ifname, "drops", 1, ifstats.stats.drops)

      -- General stats
      makeRRD(basedir, ifname, "num_hosts", 1, ifstats.stats.hosts)
      makeRRD(basedir, ifname, "num_devices", 1, ifstats.stats.devices)
      makeRRD(basedir, ifname, "num_flows", 1, ifstats.stats.flows)
      makeRRD(basedir, ifname, "num_http_hosts", 1, ifstats.stats.http_hosts)

      -- TCP stats
      makeRRD(basedir, ifname, "tcp_retransmissions", 1, ifstats.tcpPacketStats.retransmissions)
      makeRRD(basedir, ifname, "tcp_ooo", 1, ifstats.tcpPacketStats.out_of_order)
      makeRRD(basedir, ifname, "tcp_lost", 1, ifstats.tcpPacketStats.lost)

      -- ZMQ stats
      if ifstats.zmqRecvStats ~= nil then
            local name = fixPath(basedir .. "/num_zmq_received_flows.rrd")
            create_rrd(name, 1, "num_flows")
            ntop.rrd_update(name, "N:".. tolongint(ifstats.zmqRecvStats.flows))
      end
   end
end -- for _,ifname in pairs(ifnames) do
