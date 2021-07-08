--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local alert_utils = require "alert_utils"
local json = require("dkjson")
local ts_utils = require("ts_utils_core")
local plugins_utils = require("plugins_utils")
local periodic_activities_utils = require "periodic_activities_utils"
local cpu_utils = require("cpu_utils")
local callback_utils = require("callback_utils")
local recording_utils = require("recording_utils")
local alert_consts = require("alert_consts")
local rest_utils = require("rest_utils")
local auth = require "auth"

--
-- Read information about an interface
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/get/interface/data.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]
local iffilter = _GET["iffilter"]

if isEmptyString(ifid) and isEmptyString(iffilter) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

local function userHasRestrictions()
   local allowed_nets = ntop.getPref("ntopng.user." .. (_SESSION["user"] or "") .. ".allowed_nets")

   for _, net in pairs(split(allowed_nets, ",")) do
      if not isEmptyString(net) and net ~= "0.0.0.0/0" and net ~= "::/0" then
         return true
      end
   end

   return false
end

local function countHosts()
   local res = {
      local_hosts = 0,
      hosts = 0,
   }

   for host, info in callback_utils.getHostsIterator(false --[[no details]]) do
      if info.localhost then
         res.local_hosts = res.local_hosts + 1
      end

      res.hosts = res.hosts + 1
   end

   return res
end

function dumpInterfaceStats(ifid)
   local interface_name = getInterfaceName(ifid)  
   interface.select(ifid..'')

   local ifstats = interface.getStats()

   local res = {}
   if(ifstats ~= nil) then
      local uptime = ntop.getUptime()
      local prefs = ntop.getPrefs()

      -- Round up
      local hosts_pctg = math.floor(1+((ifstats.stats.hosts*100)/prefs.max_num_hosts))
      local flows_pctg = math.floor(1+((ifstats.stats.flows*100)/prefs.max_num_flows))
      local macs_pctg = math.floor(1+((ifstats.stats.current_macs*100)/prefs.max_num_hosts))

      res["ifid"]  = ifid
      res["ifname"]  = interface_name
      res["speed"]  = getInterfaceSpeed(ifstats.id)
      res["periodic_stats_update_frequency_secs"] = ifstats.periodic_stats_update_frequency_secs
      -- network load is used by web pages that are shown to the user
      -- so we must return statistics since the latest (possible) reset
      res["packets"] = ifstats.stats_since_reset.packets
      res["bytes"]   = ifstats.stats_since_reset.bytes
      res["drops"]   = ifstats.stats_since_reset.drops

      if ifstats.stats_since_reset.discarded_probing_packets then
	 res["discarded_probing_packets"] = ifstats.stats_since_reset.discarded_probing_packets
	 res["discarded_probing_bytes"]   = ifstats.stats_since_reset.discarded_probing_bytes
      end

      res["throughput_bps"] = ifstats.stats.throughput_bps;
      res["throughput_pps"] = ifstats.stats.throughput_pps;

      if prefs.is_dump_flows_enabled == true then
         res["flow_export_drops"]  = ifstats.stats_since_reset.flow_export_drops
         res["flow_export_rate"]   = ifstats.stats_since_reset.flow_export_rate
         res["flow_export_count"]  = ifstats.stats_since_reset.flow_export_count
      end

      if auth.has_capability(auth.capabilities.alerts) then
         res["engaged_alerts"]     = ifstats["num_alerts_engaged"] or 0
         res["dropped_alerts"]     = ifstats["num_dropped_alerts"] or 0
	 res["host_dropped_alerts"]  = ifstats["num_host_dropped_alerts"] or 0
	 res["flow_dropped_alerts"]  = ifstats["num_flow_dropped_alerts"] or 0
	 res["other_dropped_alerts"] = ifstats["num_other_dropped_alerts"] or 0

	 -- Active flow alerts: total
	 res["alerted_flows"]         = ifstats["num_alerted_flows"] or 0

	 -- Active flow alerts: breakdown
	 res["alerted_flows_notice"]  = ifstats["num_alerted_flows_notice"]  or 0
	 res["alerted_flows_warning"] = ifstats["num_alerted_flows_warning"] or 0
	 res["alerted_flows_error"]   = ifstats["num_alerted_flows_error"]   or 0
      end

      if periodic_activities_utils.have_degraded_performance() then
	 res["degraded_performance"] = true
      end

      if not userHasRestrictions() then
         res["num_flows"]        = ifstats.stats.flows
         res["num_hosts"]        = ifstats.stats.hosts
         res["num_local_hosts"]  = ifstats.stats.local_hosts
         res["num_devices"]      = ifstats.stats.devices
      else
         local num_hosts = countHosts()
         res["num_hosts"]        = num_hosts.hosts
         res["num_local_hosts"]  = num_hosts.local_hosts
      end

      res["epoch"]      = os.time()
      res["localtime"]  = os.date("%H:%M:%S %z", res["epoch"])
      res["uptime"]     = secondsToTime(uptime)
      if ntop.isPro() then
	 local product_info = ntop.getInfo(true)

	 if product_info["pro.out_of_maintenance"] then
	    res["out_of_maintenance"] = true
	 end
      end
      res["system_host_stats"] = cpu_utils.systemHostStats()
      res["hosts_pctg"] = hosts_pctg
      res["flows_pctg"] = flows_pctg
      res["macs_pctg"] = macs_pctg
      res["remote_pps"] = ifstats.remote_pps
      res["remote_bps"] = ifstats.remote_bps
      res["is_view"]    = ifstats.isView

      if isAdministrator() then
         res["num_live_captures"]    = ifstats.stats.num_live_captures
      end

      res["local2remote"] = ifstats["localstats"]["bytes"]["local2remote"]
      res["remote2local"] = ifstats["localstats"]["bytes"]["remote2local"]
      res["bytes_upload"] = ifstats["eth"]["egress"]["bytes"]
      res["bytes_download"] = ifstats["eth"]["ingress"]["bytes"]
      res["packets_upload"] = ifstats["eth"]["egress"]["packets"]
      res["packets_download"] = ifstats["eth"]["ingress"]["packets"]

      res["num_local_hosts_anomalies"] = ifstats.anomalies.num_local_hosts_anomalies
      res["num_remote_hosts_anomalies"] = ifstats.anomalies.num_remote_hosts_anomalies
      
      local ingress_thpt = ifstats["eth"]["ingress"]["throughput"]
      local egress_thpt  = ifstats["eth"]["egress"]["throughput"]
      res["throughput"] = {
	 download = {
	    bps = ingress_thpt["bps"], bps_trend = ingress_thpt["bps_trend"],
	    pps = ingress_thpt["pps"], pps_trend = ingress_thpt["pps_trend"]
	 },
	 upload = {
	    bps = egress_thpt["bps"], bps_trend = egress_thpt["bps_trend"],
	    pps = egress_thpt["pps"], pps_trend = egress_thpt["pps_trend"]
	 },
      }

      if ntop.isnEdge() and ifstats.type == "netfilter" and ifstats.netfilter then
         res["netfilter"] = ifstats.netfilter
      end

      if(ifstats.zmqRecvStats ~= nil) then

         if ifstats.zmqRecvStats_since_reset then
            -- override stats with the values calculated from the latest user reset 
            -- for consistency with if_stats.lua
            for k, v in pairs(ifstats.zmqRecvStats_since_reset) do
               ifstats.zmqRecvStats[k] = v
            end
         end

         res["zmqRecvStats"] = {}
         res["zmqRecvStats"]["flows"] = ifstats.zmqRecvStats.flows
         res["zmqRecvStats"]["dropped_flows"] = ifstats.zmqRecvStats.dropped_flows
	 res["zmqRecvStats"]["events"] = ifstats.zmqRecvStats.events
	 res["zmqRecvStats"]["counters"] = ifstats.zmqRecvStats.counters
	 res["zmqRecvStats"]["zmq_msg_rcvd"] = ifstats.zmqRecvStats.zmq_msg_rcvd
	 res["zmqRecvStats"]["zmq_msg_drops"] = ifstats.zmqRecvStats.zmq_msg_drops
	 res["zmqRecvStats"]["zmq_avg_msg_flows"] = math.max(1, ifstats.zmqRecvStats.flows / (ifstats.zmqRecvStats.zmq_msg_rcvd + 1))

	 res["zmq.num_flow_exports"] = ifstats["zmq.num_flow_exports"] or 0
         res["zmq.num_exporters"] = ifstats["zmq.num_exporters"] or 0

	 res["zmq.drops.export_queue_full"] = ifstats["zmq.drops.export_queue_full"] or 0
	 res["zmq.drops.flow_collection_drops"] = ifstats["zmq.drops.flow_collection_drops"] or 0
	 res["zmq.drops.flow_collection_udp_socket_drops"] = ifstats["zmq.drops.flow_collection_udp_socket_drops"] or 0
      end

      res["tcpPacketStats"] = {}
      res["tcpPacketStats"]["retransmissions"] = ifstats.tcpPacketStats.retransmissions
      res["tcpPacketStats"]["out_of_order"]    = ifstats.tcpPacketStats.out_of_order
      res["tcpPacketStats"]["lost"]            = ifstats.tcpPacketStats.lost

      if interface.isSyslogInterface() then
        res["syslog"] = {}
        res["syslog"]["tot_events"] = ifstats.syslog.tot_events
        res["syslog"]["malformed"] = ifstats.syslog.malformed
        res["syslog"]["dispatched"] = ifstats.syslog.dispatched
        res["syslog"]["unhandled"] = ifstats.syslog.unhandled
        res["syslog"]["alerts"] = ifstats.syslog.alerts
        res["syslog"]["host_correlations"] = ifstats.syslog.host_correlations
        res["syslog"]["flows"] = ifstats.syslog.flows
      end

      if(ifstats["profiles"] ~= nil) then
         res["profiles"] = ifstats["profiles"]
      end

      if recording_utils.isAvailable() then
         if recording_utils.isEnabled(ifstats.id) then
            if recording_utils.isActive(ifstats.id) then
               res["traffic_recording"] = "recording"
            else
               res["traffic_recording"] = "failed"
            end
         end

         if recording_utils.isEnabled(ifstats.id) then
            local jobs_info = recording_utils.extractionJobsInfo(ifstats.id)
            if jobs_info.ready > 0 then
               res["traffic_extraction"] = "ready"
            elseif jobs_info.total > 0 then
               res["traffic_extraction"] = jobs_info.total
            end
            res["traffic_extraction_num_tasks"] = jobs_info.total
         end
      end
   end

   return res
end

-- ###############################

if(iffilter == "all") then
   for cur_ifid, ifname in pairs(interface.getIfNames()) do
      -- ifid in the key must be a string or json.encode will think
      -- its a lua array and will look for integers starting at one
      res[cur_ifid..""] = dumpInterfaceStats(cur_ifid)
   end
elseif not isEmptyString(iffilter) then
   res = dumpInterfaceStats(iffilter)
else
   res = dumpInterfaceStats(ifid)
end

rest_utils.answer(rc, res)
