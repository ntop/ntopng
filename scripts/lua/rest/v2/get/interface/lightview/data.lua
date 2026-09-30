--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")
local interface_utils = require("interface_utils")
local auth = require "auth"

--
-- Read interface stats aggregated from all interfaces
-- Used by lightview to refresh Interface Details (if_stats.lua?view=lightview)
-- Response is a subset of rest/v2/get/interface/data.lua
--
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/interface/lightview/data.lua
--

local rc = rest_utils.consts.success.ok
local prefs = ntop.getPrefs()

-- Use the first interface as anchor: all of its counters are replaced with the aggregates
local anchor_ifname
for ifname, _ in pairsByKeys(interface.getIfNames() or {}) do
   anchor_ifname = ifname
   break
end

if not anchor_ifname then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

interface.select(anchor_ifname)

local ifstats = interface.getStats()

if ifstats.stats and ifstats.stats_since_reset then
   for k, v in pairs(ifstats.stats_since_reset) do
      ifstats.stats[k] = v
   end
end

local info
ifstats, info = interface_utils.getLightViewStats(ifstats)

local res = {}

res["packets"] = ifstats.stats.packets
res["bytes"] = ifstats.stats.bytes
res["drops"] = info.drops
res["num_deduplicated_flows"] = ifstats.stats.num_deduplicated_flows

local tot_pkt = 0
local tot_pkt_drops = 0

for _, probes_list in pairs(ifstats.probes or {}) do
   for _, probe_info in pairs(probes_list or {}) do
      tot_pkt = tot_pkt + (probe_info["packets.total"] or 0)
      tot_pkt_drops = tot_pkt_drops + (probe_info["packets.drops"] or 0)
   end
end

res["tot_nprobe_pkts"] = tot_pkt
res["tot_pkt_drops"] = tot_pkt_drops

if ifstats.stats.discarded_probing_packets then
   res["discarded_probing_packets"] = ifstats.stats.discarded_probing_packets
   res["discarded_probing_bytes"] = ifstats.stats.discarded_probing_bytes
end

local function getExportStats(db_type)
   local s = ifstats.stats_since_reset[db_type] or {}
   return {
      flow_export_count = s.flow_export_count or 0,
      flow_export_drops = s.flow_export_drops or 0,
      flow_export_rate = s.flow_export_rate or 0
   }
end

if ntop.isClickHouseEnabled() then
   res["db"] = getExportStats("db")
end
if prefs.is_dump_flows_to_es_enabled then
   res["es"] = getExportStats("es")
end
if prefs.is_dump_flows_to_kafka_enabled then
   res["kafka"] = getExportStats("kafka")
end
if prefs.is_dump_flows_to_syslog_enabled then
   res["syslog"] = getExportStats("syslog")
end

if auth.has_capability(auth.capabilities.alerts) then
   res["engaged_alerts"] = ifstats.num_alerts_engaged or 0
   res["dropped_alerts"] = ifstats.num_dropped_alerts or 0
end

res["remote_pps"] = ifstats.remote_pps
res["remote_bps"] = ifstats.remote_bps

res["bytes_upload"] = ifstats.eth.egress.bytes
res["bytes_download"] = ifstats.eth.ingress.bytes
res["packets_upload"] = ifstats.eth.egress.packets
res["packets_download"] = ifstats.eth.ingress.packets
res["bytes_upload_since_reset"] = ifstats.traffic_sent_since_reset
res["bytes_download_since_reset"] = ifstats.traffic_rcvd_since_reset
res["packets_upload_since_reset"] = ifstats.packets_sent_since_reset
res["packets_download_since_reset"] = ifstats.packets_rcvd_since_reset

res["num_local_hosts_anomalies"] = ifstats.anomalies.num_local_hosts_anomalies
res["num_remote_hosts_anomalies"] = ifstats.anomalies.num_remote_hosts_anomalies

if table.len(ifstats.zmqRecvStats) > 0 then
   local zmq = ifstats.zmqRecvStats

   res["zmqRecvStats"] = {
      flows = zmq.flows,
      dropped_flows = zmq.dropped_flows,
      events = zmq.events,
      counters = zmq.counters,
      zmq_msg_rcvd = zmq.zmq_msg_rcvd,
      zmq_msg_drops = zmq.zmq_msg_drops,
      zmq_avg_msg_flows = math.max(1, (zmq.flows or 0) / ((zmq.zmq_msg_rcvd or 0) + 1))
   }

   res["zmq.num_flow_exports"] = ifstats["zmq.num_flow_exports"]
   res["zmq.drops.export_queue_full"] = ifstats["zmq.drops.export_queue_full"]
   res["zmq.drops.flow_collection_drops"] = ifstats["zmq.drops.flow_collection_drops"]
   res["zmq.drops.flow_collection_udp_socket_drops"] = ifstats["zmq.drops.flow_collection_udp_socket_drops"]
end

res["tcpPacketStats"] = {
   retransmissions = ifstats.tcpPacketStats.retransmissions,
   out_of_order = ifstats.tcpPacketStats.out_of_order,
   lost = ifstats.tcpPacketStats.lost
}

res["ifaces"] = info.ifaces

rest_utils.answer(rc, res)
