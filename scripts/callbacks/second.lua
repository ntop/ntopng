--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if (ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
end

require "lua_utils"
require "graph_utils"
local callback_utils = require "callback_utils"

-- Toggle debug
enable_second_debug = false

if((_GET ~= nil) and (_GET["verbose"] ~= nil)) then
   enable_second_debug = true
end

if(enable_second_debug) then
   sendHTTPHeader('text/plain')
end

local ifnames = interface.getIfNames()

callback_utils.foreachInterface(ifnames, enable_second_debug, function(_ifname, ifstats)
   if(enable_second_debug) then print("Processing "..ifname.."\n") end
      -- tprint(ifstats)
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

      -- ZMQ stats
      if ifstats.zmqRecvStats ~= nil then
            local name = fixPath(basedir .. "/num_zmq_received_flows.rrd")
            create_rrd(name, 1, "num_flows")
            ntop.rrd_update(name, "N:".. tolongint(ifstats.zmqRecvStats.flows))
      else
	-- Packet interface
	makeRRD(basedir, ifname, "drops", 1, ifstats.stats.drops)
      end
end)
