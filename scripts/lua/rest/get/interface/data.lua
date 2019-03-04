--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")

sendHTTPHeader('application/json')

local callback_utils = require("callback_utils")
local recording_utils = require("recording_utils")
local remote_assistance = require("remote_assistance")

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

function dumpInterfaceStats(interface_name)
   interface.select(interface_name)

   local ifstats = interface.getStats()

   local res = {}
   if(ifstats ~= nil) then
      local uptime = ntop.getUptime()
      local prefs = ntop.getPrefs()

      -- Round up
      local hosts_pctg = math.floor(1+((ifstats.stats.hosts*100)/prefs.max_num_hosts))
      local flows_pctg = math.floor(1+((ifstats.stats.flows*100)/prefs.max_num_flows))
      local macs_pctg = math.floor(1+((ifstats.stats.current_macs*100)/prefs.max_num_hosts))

      res["ifname"]  = interface_name
      res["speed"]  = getInterfaceSpeed(ifstats.id)
      -- network load is used by web pages that are shown to the user
      -- so we must return statistics since the latest (possible) reset
      res["packets"] = ifstats.stats_since_reset.packets
      res["bytes"]   = ifstats.stats_since_reset.bytes
      res["drops"]   = ifstats.stats_since_reset.drops
      
      if prefs.is_dump_flows_enabled == true then
	  res["flow_export_drops"]  = ifstats.stats_since_reset.flow_export_drops
	  res["flow_export_rate"]   = ifstats.stats_since_reset.flow_export_rate
	  res["flow_export_count"]  = ifstats.stats_since_reset.flow_export_count
      end

      if prefs.are_alerts_enabled == true then
	 local alert_cache = interface.getCachedNumAlerts() or {}
	 res["engaged_alerts"]     = alert_cache["num_alerts_engaged"] or 0
	 res["alerts_stored"]      = alert_cache["alerts_stored"] or 0
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
      res["system_host_stats"] = ntop.systemHostStat()
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

      if ntop.isnEdge() and ifstats.type == "netfilter" and ifstats.netfilter then
	 res["netfilter"] = ifstats.netfilter
      end

      if(ifstats.zmqRecvStats ~= nil) then
	 res["zmqRecvStats"] = {}
	 res["zmqRecvStats"]["flows"] = ifstats.zmqRecvStats.flows
	 res["zmqRecvStats"]["events"] = ifstats.zmqRecvStats.events
	 res["zmqRecvStats"]["counters"] = ifstats.zmqRecvStats.counters
	 res["zmqRecvStats"]["zmq_msg_drops"] = ifstats.zmqRecvStats.zmq_msg_drops

	 res["zmq.num_flow_exports"] = ifstats["zmq.num_flow_exports"] or 0
	 res["zmq.num_exporters"] = ifstats["zmq.num_exporters"] or 0
      end
      
      res["tcpPacketStats"] = {}
      res["tcpPacketStats"]["retransmissions"] = ifstats.tcpPacketStats.retransmissions
      res["tcpPacketStats"]["out_of_order"]    = ifstats.tcpPacketStats.out_of_order
      res["tcpPacketStats"]["lost"]            = ifstats.tcpPacketStats.lost

      if(ifstats["profiles"] ~= nil) then
	 res["profiles"] = ifstats["profiles"]
      end

      if remote_assistance.isAvailable() then
	 if remote_assistance.isEnabled() then
	    res["remote_assistance"] = {
	       status = remote_assistance.getStatus(),
	    }
	 end
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

local res = {}
if(_GET["iffilter"] == "all") then
   for _, ifname in pairs(interface.getIfNames()) do
      local ifid = getInterfaceId(ifname)
      -- ifid in the key must be a string or json.encode will think
      -- its a lua array and will look for integers starting at one
      res[ifid..""] = dumpInterfaceStats(ifname)
   end
elseif not isEmptyString(_GET["iffilter"]) then
   res = dumpInterfaceStats(getInterfaceName(_GET["iffilter"]))
else
   local ifname = nil
   if not isEmptyString(_GET["ifid"]) then
     ifname = getInterfaceName(_GET["ifid"])
   end
   res = dumpInterfaceStats(ifname)
end
print(json.encode(res))
