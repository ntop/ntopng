--
-- (C) 2013-17 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- do NOT include lua_utils here, it's not necessary, keep it light!
local rrd_utils = require "rrd_utils"
local os_utils = require "os_utils"
local callback_utils = require "callback_utils"

-- Toggle debug
local enable_second_debug = false

local ifnames = interface.getIfNames()
local when = os.time()

callback_utils.foreachInterface(ifnames, interface_rrd_creation_enabled, function(ifname, ifstats)
   if(enable_second_debug) then print("Processing "..ifname.."\n") end
   -- tprint(ifstats)
   basedir = os_utils.fixPath(dirs.workingdir .. "/" .. ifstats.id .. "/rrd")
   
   --io.write(basedir.."\n")
   if(not(ntop.exists(basedir))) then
      if(enable_second_debug) then io.write('Creating base directory ', basedir, '\n') end
      ntop.mkdir(basedir)
   end
   
   -- Traffic stats
   rrd_utils.makeRRD(basedir, when, ifstats.id, "iface", "bytes", 1, ifstats.stats.bytes)
   rrd_utils.makeRRD(basedir, when, ifstats.id, "iface", "packets", 1, ifstats.stats.packets)
   
   -- ZMQ stats
   if ifstats.zmqRecvStats ~= nil then
      rrd_utils.makeRRD(basedir, when, ifstats.id, "iface", "num_zmq_rcvd_flows",
			1, tolongint(ifstats.zmqRecvStats.flows))
   else
      -- Packet interface
      rrd_utils.makeRRD(basedir, when, ifstats.id, "iface", "drops", 1, ifstats.stats.drops)
   end
end)

ntop.tsFlush(tonumber(1))
