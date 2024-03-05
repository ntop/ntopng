--
-- (C) 2019-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/vulnerability_scan/?.lua;" .. package.path

-- ############################################

local topic = "test.interface.stats"

-- ############################################
-- Requires

require "ntop_utils"
local periodic_activities_utils = require "periodic_activities_utils"
local callback_utils = require("callback_utils")
local recording_utils = require("recording_utils")
local auth = require "auth"
local vs_utils = require "vs_utils"
local json = require("dkjson")

-- ############################################

if (ntop.getPref("ntopng.prefs.toggle_message_broker") ~= "1") then
   return
end

-- ############################################

local function userHasRestrictions()
   local allowed_nets = ntop.getPref("ntopng.user.admin.allowed_nets")

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

local function format_info(ifstats)

  local ifstats = interface.getStats()
  local interface_name = getInterfaceName(ifstats.id)  

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

    res["drops"]   = ifstats.stats_since_reset.drops

    res["throughput_bps"] = ifstats.stats.throughput_bps;
   if (vs_utils.is_available()) then
      local total, total_in_progress = vs_utils.check_in_progress_status()
      res["vs_in_progress"] = total_in_progress or 0
   end
    if prefs.is_dump_flows_enabled == true then
        res["flow_export_drops"]  = ifstats.stats_since_reset.flow_export_drops
        res["flow_export_count"]  = ifstats.stats_since_reset.flow_export_count
    end

    if auth.has_capability(auth.capabilities.alerts) then
      res["engaged_alerts"]     = ifstats["num_alerts_engaged"] or 0
      res["engaged_alerts_warning"] = ifstats["num_alerts_engaged_by_severity"]["warning"]
      res["engaged_alerts_error"]   = ifstats["num_alerts_engaged_by_severity"]["error"]

      res["alerted_flows"]         = ifstats["num_alerted_flows"] or 0
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
      res["num_rcvd_only_hosts"]  = ifstats.stats.hosts_rcvd_only
      res["num_local_rcvd_only_hosts"] = ifstats.stats.local_rcvd_only_hosts
    else
      res["num_hosts"]        = countHosts().hosts
      res["num_local_hosts"]  = countHosts().local_hosts
    end

    res["localtime"]  = os.date("%H:%M:%S %z", res["epoch"])
    res["uptime"]     = secondsToTime(uptime)
    if ntop.isPro() then
      local product_info = ntop.getInfo(true)
      if product_info["pro.out_of_maintenance"] then
        res["out_of_maintenance"] = true
      end
    end

    res["hosts_pctg"] = hosts_pctg
    res["flows_pctg"] = flows_pctg
    res["macs_pctg"] = macs_pctg

    if isAdministrator() then
        res["num_live_captures"]    = ifstats.stats.num_live_captures
    end
    
    local ingress_thpt = ifstats["eth"]["ingress"]["throughput"]
    local egress_thpt  = ifstats["eth"]["egress"]["throughput"]
    res["throughput"] = {
      download = ingress_thpt["bps"],
      upload = egress_thpt["bps"]
    }
        
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
    -- Adding a preference if active discovery is enabled
    res["active_discovery_active"] = ntop.getPref("ntopng.prefs.is_periodic_network_discovery_running.ifid_" .. interface.getId()) == "1"
  end
  return res
end


-- #############################################
-- Retrieves interface stats and 
--    sends them to message broker (nats)

local iface_info = interface.getStats()

ntop.publish(topic,json.encode(format_info(iface_info)))

-- #############################################
