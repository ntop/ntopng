--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path
require "lua_utils"
-- do NOT include lua_utils here, it's not necessary, keep it light!
local callback_utils = require "callback_utils"
-- Toggle debug
local enable_second_debug = false
local ifnames = interface.getIfNames()

-- ###########################################

local function interface_rrd_creation_enabled(ifid)
   return (ntop.getPref("ntopng.prefs.interface_rrd_creation") ~= "0")
end

-- ###########################################

local ts_utils = require("ts_utils_core")
require("ts_second")

-- Run this script for a minute before quitting (this reduces load on Lua VM infrastructure)
local num_runs = 60

for i=1,num_runs do
   if(ntop.isShutdown()) then break end

   callback_utils.foreachInterface(ifnames, interface_rrd_creation_enabled, 
      function(ifname, ifstats)
         if(enable_second_debug) then print("Processing "..ifname.." ifid: "..ifstats.id.."\n") end

         -- Traffic stats
         -- We check for ifstats.stats.bytes to start writing only when there's data. This
         -- prevents artificial and wrong peaks especially during the startup of ntopng.
         if ifstats.stats.bytes > 0 then

            ts_utils.append("iface:traffic", {ifid=ifstats.id, bytes=ifstats.stats.bytes}, when)

            ts_utils.append("iface:throughput_bps", {ifid=ifstats.id, bps=ifstats.stats.throughput_bps}, when)

            ts_utils.append("iface:throughput_pps", {ifid=ifstats.id, pps=ifstats.stats.throughput_pps}, when)

            ts_utils.append("iface:packets_vs_drops",   {ifid=ifstats.id, packets=ifstats.stats.packets, drops=ifstats.stats.drops or 0}, when)

            if ifstats.has_traffic_directions then

               ts_utils.append("iface:traffic_rxtx", {ifid=ifstats.id,
                  bytes_sent=ifstats.eth.egress.bytes, bytes_rcvd=ifstats.eth.ingress.bytes}, when)

            end
         end

         -- ZMQ stats (only for non-packet interfaces)
         if ifstats.zmqRecvStats ~= nil and not interface.isPacketInterface() then

            ts_utils.append("iface:zmq_recv_flows", {ifid = ifstats.id, flows = ifstats.zmqRecvStats.flows or 0}, when)

            ts_utils.append("iface:zmq_rcvd_msgs", {ifid = ifstats.id, msgs = ifstats.zmqRecvStats.zmq_msg_rcvd or 0}, when)

            ts_utils.append("iface:zmq_msg_drops", {ifid = ifstats.id, msgs = ifstats.zmqRecvStats.zmq_msg_drops or 0}, when)

            ts_utils.append("iface:zmq_flow_coll_drops", {ifid = ifstats.id, drops = ifstats["zmq.drops.flow_collection_drops"] or 0}, when)

            ts_utils.append("iface:zmq_flow_coll_udp_drops", {ifid = ifstats.id, drops = ifstats["zmq.drops.flow_collection_udp_socket_drops"] or 0}, when)

         end

         -- Discarded probing stats
         if ifstats.discarded_probing_packets then

            ts_utils.append("iface:disc_prob_bytes", {ifid = ifstats.id,
               bytes = ifstats.discarded_probing_bytes}, when)

            ts_utils.append("iface:disc_prob_pkts", {ifid = ifstats.id,
               packets = ifstats.discarded_probing_packets}, when)

         end
   end, true --[[ update direction stats ]])

   if(num_runs > 1) then
      ntop.msleep(1000)
   end
end

-- Uncomment this to simulate slow downs
--os.execute('perl -e "select(undef,undef,undef,0.8);"')
