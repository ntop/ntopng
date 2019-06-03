--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

-- do NOT include lua_utils here, it's not necessary, keep it light!
local callback_utils = require "callback_utils"
local ts_utils = require("ts_utils_core")
require("ts_second")

-- Toggle debug
local enable_second_debug = false
local ifnames = interface.getIfNames()

-- NOTE: must use gettimeofday otherwise the seconds may not correspond
local when = math.floor(ntop.gettimemsec())

local function interface_rrd_creation_enabled(ifid)
   return (ntop.getPref("ntopng.prefs.ifid_"..ifid..".interface_rrd_creation") ~= "false")
      and (ntop.getPref("ntopng.prefs.interface_rrd_creation") ~= "0")
end

callback_utils.foreachInterface(ifnames, interface_rrd_creation_enabled, function(ifname, ifstats)
   if(enable_second_debug) then print("Processing "..ifname.."\n") end

   -- Traffic stats
   -- We check for ifstats.stats.bytes to start writing only when there's data. This
   -- prevents artificial and wrong peaks especially during the startup of ntopng.
   if ifstats.stats.bytes > 0 then
      ts_utils.append("iface:traffic", {ifid=ifstats.id, bytes=ifstats.stats.bytes}, when)
      ts_utils.append("iface:packets", {ifid=ifstats.id, packets=ifstats.stats.packets}, when)

      if ifstats.has_traffic_directions then
	 ts_utils.append("iface:traffic_rxtx", {ifid=ifstats.id,
						bytes_sent=ifstats.eth.egress.bytes, bytes_rcvd=ifstats.eth.ingress.bytes}, when)
      end
   end

   -- ZMQ stats
   if ifstats.zmqRecvStats ~= nil then
      ts_utils.append("iface:zmq_recv_flows", {ifid = ifstats.id, flows = ifstats.zmqRecvStats.flows or 0}, when)
      ts_utils.append("iface:zmq_flow_coll_drops", {ifid = ifstats.id, drops = ifstats["zmq.drops.flow_collection_drops"] or 0}, when)
   else
      -- Packet interface
      ts_utils.append("iface:drops", {ifid=ifstats.id, packets=ifstats.stats.drops}, when)
   end

   -- Flow export stats
   if(ifstats.stats.flow_export_count ~= nil) then
      ts_utils.append("iface:exported_flows", {ifid=ifstats.id, num_flows=ifstats.stats.flow_export_count}, when)
      ts_utils.append("iface:dropped_flows", {ifid=ifstats.id, num_flows=ifstats.stats.flow_export_drops}, when)
   end
end, true --[[ get direction stats ]])
