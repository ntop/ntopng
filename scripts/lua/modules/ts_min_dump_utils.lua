--
-- (C) 2019-20 - ntop.org
--

-- ########################################################

require "lua_utils"
require "alert_utils"
require "graph_utils"

local os_utils = require "os_utils"
local top_talkers_utils = require "top_talkers_utils"
local ts_utils = require("ts_utils_core")
local user_scripts = require("user_scripts")
require("ts_minute")

local ts_custom
if ntop.exists(dirs.installdir .. "/scripts/lua/modules/timeseries/custom/ts_minute_custom.lua") then
   package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/custom/?.lua;" .. package.path
   ts_custom = require "ts_minute_custom"
end

local ts_dump = {}

-- ########################################################

function ts_dump.iface_update_ndpi_rrds(when, _ifname, ifstats, verbose, config)
  for k in pairs(ifstats["ndpi"]) do
    local v = ifstats["ndpi"][k]["bytes.sent"]+ifstats["ndpi"][k]["bytes.rcvd"]
    if(verbose) then print("["..__FILE__()..":"..__LINE__().."] ".._ifname..": "..k.."="..v.."\n") end

    ts_utils.append("iface:ndpi", {ifid=ifstats.id, protocol=k, bytes=v}, when)

    if config.ndpi_flows_timeseries_creation == "1" then
      ts_utils.append("iface:ndpi_flows", {ifid=ifstats.id, protocol=k, num_flows=ifstats["ndpi"][k]["num_flows"]}, when)
    end
  end
end

-- ########################################################

function ts_dump.iface_update_categories_rrds(when, _ifname, ifstats, verbose)
  for k, v in pairs(ifstats["ndpi_categories"]) do
    v = v["bytes"]
    if(verbose) then print("["..__FILE__()..":"..__LINE__().."] ".._ifname..": "..k.."="..v.."\n") end

    ts_utils.append("iface:ndpi_categories", {ifid=ifstats.id, category=k, bytes=v}, when)
  end
end

-- ########################################################

function ts_dump.iface_update_stats_rrds(when, _ifname, ifstats, verbose)
  -- IN/OUT counters
  if(ifstats["localstats"]["bytes"]["local2remote"] > 0) then
    ts_utils.append("iface:local2remote", {ifid=ifstats.id, bytes=ifstats["localstats"]["bytes"]["local2remote"]}, when)
  end

  if(ifstats["localstats"]["bytes"]["remote2local"] > 0) then
    ts_utils.append("iface:remote2local", {ifid=ifstats.id, bytes=ifstats["localstats"]["bytes"]["remote2local"]}, when)
  end
end

-- ########################################################

function ts_dump.subnet_update_rrds(when, ifstats, verbose)
  local subnet_stats = interface.getNetworksStats()

  for subnet,sstats in pairs(subnet_stats) do
     ts_utils.append("subnet:traffic",
		     {ifid=ifstats.id, subnet=subnet,
		      bytes_ingress=sstats["ingress"], bytes_egress=sstats["egress"],
		      bytes_inner=sstats["inner"]}, when)

     ts_utils.append("subnet:broadcast_traffic",
		     {ifid=ifstats.id, subnet=subnet,
		      bytes_ingress=sstats["broadcast"]["ingress"], bytes_egress=sstats["broadcast"]["egress"],
		      bytes_inner=sstats["broadcast"]["inner"]}, when)

     ts_utils.append("subnet:tcp_retransmissions",
		     {ifid=ifstats.id, subnet=subnet,
		      packets_ingress=sstats["tcpPacketStats.ingress"]["retransmissions"],
		      packets_egress=sstats["tcpPacketStats.egress"]["retransmissions"],
		      packets_inner=sstats["tcpPacketStats.inner"]["retransmissions"]}, when)

     ts_utils.append("subnet:tcp_out_of_order",
		     {ifid=ifstats.id, subnet=subnet,
		      packets_ingress=sstats["tcpPacketStats.ingress"]["out_of_order"],
		      packets_egress=sstats["tcpPacketStats.egress"]["out_of_order"],
		      packets_inner=sstats["tcpPacketStats.inner"]["out_of_order"]}, when)

     ts_utils.append("subnet:tcp_lost",
		     {ifid=ifstats.id, subnet=subnet,
		      packets_ingress=sstats["tcpPacketStats.ingress"]["lost"],
		      packets_egress=sstats["tcpPacketStats.egress"]["lost"],
		      packets_inner=sstats["tcpPacketStats.inner"]["lost"]}, when)

     ts_utils.append("subnet:tcp_keep_alive",
		     {ifid=ifstats.id, subnet=subnet,
		      packets_ingress=sstats["tcpPacketStats.ingress"]["keep_alive"],
		      packets_egress=sstats["tcpPacketStats.egress"]["keep_alive"],
		      packets_inner=sstats["tcpPacketStats.inner"]["keep_alive"]}, when)

     ts_utils.append("subnet:engaged_alerts",
		     {ifid=ifstats.id, subnet=subnet,
		      alerts=sstats["engaged_alerts"]}, when)
  end
end

-- ########################################################

function ts_dump.iface_update_general_stats(when, ifstats, verbose)
  -- General stats
  ts_utils.append("iface:alerts_stats", {ifid=ifstats.id, engaged_alerts=ifstats.stats.engaged_alerts, dropped_alerts=ifstats.stats.dropped_alerts}, when)
  ts_utils.append("iface:hosts", {ifid=ifstats.id, num_hosts=ifstats.stats.hosts}, when)
  ts_utils.append("iface:local_hosts", {ifid=ifstats.id, num_hosts=ifstats.stats.local_hosts}, when)
  ts_utils.append("iface:devices", {ifid=ifstats.id, num_devices=ifstats.stats.devices}, when)
  ts_utils.append("iface:flows", {ifid=ifstats.id, num_flows=ifstats.stats.flows}, when)
  ts_utils.append("iface:http_hosts", {ifid=ifstats.id, num_hosts=ifstats.stats.http_hosts}, when)
  ts_utils.append("iface:alerted_flows", {ifid=ifstats.id, num_flows=ifstats.stats.num_alerted_flows}, when)
  ts_utils.append("iface:misbehaving_flows", {ifid=ifstats.id, num_flows=ifstats.stats.num_misbehaving_flows}, when)
end

function ts_dump.iface_update_l4_stats(when, ifstats, verbose)
  for id, _ in pairs(l4_keys) do
    k = l4_keys[id][2]
    if((ifstats.stats[k..".bytes.sent"] ~= nil) and (ifstats.stats[k..".bytes.rcvd"] ~= nil)) then
      ts_utils.append("iface:l4protos", {ifid=ifstats.id,
                -- NOTE: direction may not be correct for PCAP interfaces, so it cannot be split
                l4proto=tostring(k), bytes=ifstats.stats[k..".bytes.sent"] + ifstats.stats[k..".bytes.rcvd"]}, when)
    end
  end
end

function ts_dump.iface_update_tcp_stats(when, ifstats, verbose)
  ts_utils.append("iface:tcp_retransmissions", {ifid=ifstats.id, packets=ifstats.tcpPacketStats.retransmissions}, when)
  ts_utils.append("iface:tcp_out_of_order", {ifid=ifstats.id, packets=ifstats.tcpPacketStats.out_of_order}, when)
  ts_utils.append("iface:tcp_lost", {ifid=ifstats.id, packets=ifstats.tcpPacketStats.lost}, when)
  ts_utils.append("iface:tcp_keep_alive", {ifid=ifstats.id, packets=ifstats.tcpPacketStats.keep_alive}, when)
end

function ts_dump.iface_update_tcp_flags(when, ifstats, verbose)
  ts_utils.append("iface:tcp_syn", {ifid=ifstats.id, packets=ifstats.pktSizeDistribution.tcp_flags.syn}, when)
  ts_utils.append("iface:tcp_synack", {ifid=ifstats.id, packets=ifstats.pktSizeDistribution.tcp_flags.synack}, when)
  ts_utils.append("iface:tcp_finack", {ifid=ifstats.id, packets=ifstats.pktSizeDistribution.tcp_flags.finack}, when)
  ts_utils.append("iface:tcp_rst", {ifid=ifstats.id, packets=ifstats.pktSizeDistribution.tcp_flags.rst}, when)
end

-- ########################################################

function ts_dump.profiles_update_stats(when, ifstats, verbose)
  for pname, ptraffic in pairs(ifstats.profiles) do
    ts_utils.append("profile:traffic", {ifid=ifstats.id, profile=pname, bytes=ptraffic}, when)
  end
end

-- ########################################################

function ts_dump.update_hash_tables_stats(when, ifstats, verbose)
   local hash_tables_stats = interface.getHashTablesStats()

   for ht_name, ht_stats in pairs(hash_tables_stats) do
      local num_idle = 0
      local num_active = 0

      if ht_stats["hash_entry_states"] then
         if ht_stats["hash_entry_states"]["hash_entry_state_idle"] then
	   num_idle = ht_stats["hash_entry_states"]["hash_entry_state_idle"]
         end
         if ht_stats["hash_entry_states"]["hash_entry_state_active"] then
	   num_active = ht_stats["hash_entry_states"]["hash_entry_state_active"]
         end
      end

      ts_utils.append("ht:state", {ifid = ifstats.id, hash_table = ht_name, num_idle = num_idle, num_active = num_active}, when)
   end
end

-- ########################################################

function ts_dump.update_periodic_scripts_stats(when, ifstats, verbose)
   local periodic_scripts_stats = interface.getPeriodicActivitiesStats()
   local to_stdout = ntop.getPref("ntopng.prefs.periodic_activities_stats_to_stdout") == "1"

   for ps_name, ps_stats in pairs(periodic_scripts_stats) do
      if to_stdout then
	 local cur_ifid = interface.getId()
	 local cur_ifname
	 local rrd_out

	 if tostring(cur_ifid) == getSystemInterfaceId() then
	    cur_ifname = getSystemInterfaceName()
	 else
	    cur_ifname = getInterfaceName(cur_ifid)
	 end

	 if ps_stats["rrd"] and ps_stats["rrd"]["write"] and  ps_stats["rrd"]["write"]["last"] then
	    rrd_out = string.format("[rrd.write.tot_calls: %i][last_avg_call_duration_ms: %.2f][last_max_call_duration_ms: %.2f][rrd.write.tot_drops: %u][last_is_slow: %s]",
				    ps_stats["rrd"]["write"]["tot_calls"] or 0,
				    ps_stats["rrd"]["write"]["last"]["avg_call_duration_ms"] or 0,
				    ps_stats["rrd"]["write"]["last"]["max_call_duration_ms"] or 0,
				    ps_stats["rrd"]["write"]["tot_drops"] or 0,
				    tostring(ps_stats["rrd"]["write"]["last"]["is_slow"]))
	 end

	 if rrd_out then
	    traceError(TRACE_NORMAL, TRACE_CONSOLE, string.format("[ifname: %s][ifid: %i][%s]%s", cur_ifname, cur_ifid, ps_name, rrd_out))
	 end
      end

      -- Write info on the script duration
      local num_ms_last = 0

      if ps_stats["duration"] then
	 if ps_stats["duration"]["last_duration_ms"] then
	   num_ms_last = ps_stats["duration"]["last_duration_ms"]
	 end
      end

      ts_utils.append("periodic_script:duration", {ifid = ifstats.id, periodic_script = ps_name, num_ms_last = num_ms_last}, when)

      -- Only if RRD is enabled, also total number of writes and dropped points are written
      if ts_utils.getDriverName() == "rrd" then
	 if ps_stats["rrd"] and ps_stats["rrd"]["write"] then
	    ts_utils.append("periodic_script:rrd_writes", {ifid = ifstats.id, periodic_script = ps_name, writes = (ps_stats["rrd"]["write"]["tot_calls"] or 0), drops = (ps_stats["rrd"]["write"]["tot_drops"] or 0)}, when)
	 end
      end
   end
end

-- ########################################################

function ts_dump.containers_update_stats(when, ifstats, verbose)
  local containers_stats = interface.getContainersStats()

  for container_id, container in pairs(containers_stats) do
    ts_utils.append("container:num_flows", {ifid=ifstats.id, container=container_id,
      as_client=container["num_flows.as_client"], as_server=container["num_flows.as_server"]
    }, when)

    ts_utils.append("container:rtt", {ifid=ifstats.id, container=container_id,
      as_client=container["rtt_as_client"], as_server=container["rtt_as_server"]
    }, when)

    ts_utils.append("container:rtt_variance", {ifid=ifstats.id, container=container_id,
      as_client=container["rtt_variance_as_client"], as_server=container["rtt_variance_as_server"]
    }, when)
  end
end

-- ########################################################

function ts_dump.pods_update_stats(when, ifstats, verbose)
  local pods_stats = interface.getPodsStats()

  for pod_id, pod in pairs(pods_stats) do
    ts_utils.append("pod:num_containers", {ifid=ifstats.id, pod=pod_id,
      num_containers=pod["num_containers"],
    }, when)

    ts_utils.append("pod:num_flows", {ifid=ifstats.id, pod=pod_id,
      as_client=pod["num_flows.as_client"], as_server=pod["num_flows.as_server"]
    }, when)

    ts_utils.append("pod:rtt", {ifid=ifstats.id, pod=pod_id,
      as_client=pod["rtt_as_client"], as_server=pod["rtt_as_server"]
    }, when)

    ts_utils.append("pod:rtt_variance", {ifid=ifstats.id, pod=pod_id,
      as_client=pod["rtt_variance_as_client"], as_server=pod["rtt_variance_as_server"]
    }, when)
  end
end

-- ########################################################

local function update_user_scripts_stats(when, ifid, verbose)
  -- NOTE: flow scripts are monitored in 5sec.lua
  local all_scripts = {
    host = user_scripts.script_types.traffic_element,
    interface = user_scripts.script_types.traffic_element,
    network = user_scripts.script_types.traffic_element,
  }

  user_scripts.ts_dump(when, ifid, verbose, "elem_user_script", all_scripts)
end

-- ########################################################

local function dumpTopTalkers(_ifname, ifstats, verbose)
  -- Dump topTalkers every minute
   local talkers = top_talkers_utils.makeTopJson(_ifname)

   if talkers then
      if(verbose) then
	 print("Computed talkers for interfaceId "..ifstats.id.."/"..ifstats.name.."\n")
	 print(talkers)
      end

      ntop.insertMinuteSampling(ifstats.id, talkers)
   end
end

function ts_dump.run_min_dump(_ifname, ifstats, iface_ts, config, when)
  dumpTopTalkers(_ifname, ifstats, verbose)

  user_scripts.runPeriodicScripts("min")
  check_macs_alerts(ifstats.id)
  check_host_pools_alerts(ifstats.id)

  local iface_rrd_creation_enabled = areInterfaceTimeseriesEnabled(ifstats.id)

  if not iface_rrd_creation_enabled then
    return
  end

  ts_dump.subnet_update_rrds(when, ifstats, verbose)
  for _, iface_point in ipairs(iface_ts or {}) do
    local instant = iface_point.instant

    -- compatibility fix with ifstats
    iface_point.id = ifstats.id

    ts_dump.iface_update_stats_rrds(instant, _ifname, iface_point, verbose)
    ts_dump.iface_update_general_stats(instant, iface_point, verbose)
    ts_dump.iface_update_l4_stats(instant, iface_point, verbose)

    if config.interface_ndpi_timeseries_creation == "per_protocol" or config.interface_ndpi_timeseries_creation == "both" then
      ts_dump.iface_update_ndpi_rrds(instant, _ifname, iface_point, verbose, config)
    end

    if config.interface_ndpi_timeseries_creation == "per_category" or config.interface_ndpi_timeseries_creation == "both" then
      ts_dump.iface_update_categories_rrds(instant, _ifname, iface_point, verbose)
    end

    if((not ifstats.has_seen_ebpf_events) or (ifstats.type ~= "zmq")) then
       -- TCP stats
      if config.tcp_retr_ooo_lost_rrd_creation == "1" then
        ts_dump.iface_update_tcp_stats(instant, iface_point, verbose)
      end

      -- TCP Flags
      if config.tcp_flags_rrd_creation == "1" then
        ts_dump.iface_update_tcp_flags(instant, iface_point, verbose)
      end
    end

    -- create custom rrds
    if ts_custom and ts_custom.iface_update_stats then
       ts_custom.iface_update_stats(instant, _ifname, iface_point, verbose)
    end
  end

  -- Save internal hash tables states every minute
  ts_dump.update_hash_tables_stats(when, ifstats, verbose)

  -- Save the traffic elements user scripts stats
  if config.user_scripts_rrd_creation then
     update_user_scripts_stats(when, ifstats.id, verbose)
  end

  -- Save duration of periodic scripts
  ts_dump.update_periodic_scripts_stats(when, ifstats, verbose)

  -- Save Profile stats every minute
  if ntop.isPro() and ifstats.profiles then  -- profiles are only available in the Pro version
    ts_dump.profiles_update_stats(when, ifstats, verbose)
  end

  -- Containers/Pods stats
  if ifstats.has_seen_containers then
    ts_dump.containers_update_stats(when, ifstats, verbose)
  end
  if ifstats.has_seen_pods then
    ts_dump.pods_update_stats(when, ifstats, verbose)
  end

  if ntop.isnEdge() and ifstats.type == "netfilter" and ifstats.netfilter then
     local st = ifstats.netfilter.nfq or {}

     ts_utils.append("iface:nfq_pct", {ifid=ifstats.id, num_nfq_pct = st.queue_pct}, when)
  end
end

-- ########################################################

function ts_dump.getConfig()
  local config = {}

  config.interface_ndpi_timeseries_creation = ntop.getPref("ntopng.prefs.interface_ndpi_timeseries_creation")
  config.tcp_flags_rrd_creation = ntop.getPref("ntopng.prefs.tcp_flags_rrd_creation")
  config.tcp_retr_ooo_lost_rrd_creation = ntop.getPref("ntopng.prefs.tcp_retr_ooo_lost_rrd_creation")
  config.ndpi_flows_timeseries_creation = ntop.getPref("ntopng.prefs.ndpi_flows_rrd_creation")
  config.user_scripts_rrd_creation = ntop.getPref("ntopng.prefs.user_scripts_rrd_creation") == "1"

  -- Interface RRD creation is on, with per-protocol nDPI
  if isEmptyString(config.interface_ndpi_timeseries_creation) then config.interface_ndpi_timeseries_creation = "per_protocol" end

  return config
end

-- ########################################################

return ts_dump
