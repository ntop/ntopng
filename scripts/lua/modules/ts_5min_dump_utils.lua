require "lua_utils"
require "graph_utils"
require "alert_utils"
local host_pools_utils = require "host_pools_utils"
local callback_utils = require "callback_utils"
local ts_utils = require "ts_utils_core"
local format_utils = require "format_utils"
local user_scripts = require("user_scripts")
require "ts_5min"

-- Set to true to debug host timeseries points timestamps
local enable_debug = false

local ts_custom
if ntop.exists(dirs.installdir .. "/scripts/lua/modules/timeseries/custom/ts_5min_custom.lua") then
   package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/custom/?.lua;" .. package.path
   ts_custom = require "ts_5min_custom"
end

local dirs = ntop.getDirs()
local ts_dump = {}

-- ########################################################

function ts_dump.l2_device_update_categories_rrds(when, devicename, device, ifstats, verbose)
  -- nDPI Protocol CATEGORIES
  for k, cat in pairs(device["ndpi_categories"] or {}) do
    ts_utils.append("mac:ndpi_categories", {ifid=ifstats.id, mac=devicename, category=k,
              bytes=cat["bytes"]}, when, verbose)
  end
end

function ts_dump.l2_device_update_stats_rrds(when, devicename, device, ifstats, verbose)
  ts_utils.append("mac:traffic", {ifid=ifstats.id, mac=devicename,
              bytes_sent=device["bytes.sent"], bytes_rcvd=device["bytes.rcvd"]}, when, verbose)
  
  ts_utils.append("mac:arp_rqst_sent_rcvd_rpls", {ifid=ifstats.id, mac=devicename,
              request_packets_sent = device["arp_requests.sent"],
              reply_packets_rcvd = device["arp_replies.rcvd"]},
        when,verbose)
end

-- ########################################################

function ts_dump.asn_update_rrds(when, ifstats, verbose)
  local asn_info = interface.getASesInfo({detailsLevel = "higher"})

  for _, asn_stats in pairs(asn_info["ASes"]) do
    local asn = asn_stats["asn"]

    -- Save ASN bytes
    ts_utils.append("asn:traffic", {ifid=ifstats.id, asn=asn,
              bytes_sent=asn_stats["bytes.sent"], bytes_rcvd=asn_stats["bytes.rcvd"]}, when)

    -- Save ASN ndpi stats
    if asn_stats["ndpi"] ~= nil then
      for proto_name, proto_stats in pairs(asn_stats["ndpi"]) do
        ts_utils.append("asn:ndpi", {ifid=ifstats.id, asn=asn, protocol=proto_name,
                  bytes_sent=proto_stats["bytes.sent"], bytes_rcvd=proto_stats["bytes.rcvd"]}, when, verbose)
      end
    end

    -- Save ASN RTT stats
    ts_utils.append("asn:rtt",
		    {ifid=ifstats.id, asn=asn,
		     millis_rtt=asn_stats["round_trip_time"]}, when, verbose)

    -- Save ASN TCP stats
    ts_utils.append("asn:tcp_retransmissions",
		    {ifid=ifstats.id, asn=asn,
		     packets_sent=asn_stats["tcpPacketStats.sent"]["retransmissions"],
		     packets_rcvd=asn_stats["tcpPacketStats.rcvd"]["retransmissions"]}, when, verbose)

    ts_utils.append("asn:tcp_out_of_order",
		    {ifid=ifstats.id, asn=asn,
		     packets_sent=asn_stats["tcpPacketStats.sent"]["out_of_order"],
		     packets_rcvd=asn_stats["tcpPacketStats.rcvd"]["out_of_order"]}, when, verbose)

    ts_utils.append("asn:tcp_lost",
		    {ifid=ifstats.id, asn=asn,
		     packets_sent=asn_stats["tcpPacketStats.sent"]["lost"],
		     packets_rcvd=asn_stats["tcpPacketStats.rcvd"]["lost"]}, when, verbose)

    ts_utils.append("asn:tcp_keep_alive",
		    {ifid=ifstats.id, asn=asn,
		     packets_sent=asn_stats["tcpPacketStats.sent"]["keep_alive"],
		     packets_rcvd=asn_stats["tcpPacketStats.rcvd"]["keep_alive"]}, when, verbose)
  end
end

-- ########################################################

function ts_dump.country_update_rrds(when, ifstats, verbose)
  local countries_info = interface.getCountriesInfo({detailsLevel = "higher", sortColumn = "column_country"})

  for _, country_stats in pairs(countries_info["Countries"] or {}) do
    local country = country_stats.country

    ts_utils.append("country:traffic", {ifid=ifstats.id, country=country,
                bytes_ingress=country_stats["ingress"], bytes_egress=country_stats["egress"],
                bytes_inner=country_stats["inner"]}, when, verbose)
  end
end

-- ########################################################

function ts_dump.vlan_update_rrds(when, ifstats, verbose)
  local vlan_info = interface.getVLANsInfo()

  if(vlan_info ~= nil) and (vlan_info["VLANs"] ~= nil) then
    for _, vlan_stats in pairs(vlan_info["VLANs"]) do
      local vlan_id = vlan_stats["vlan_id"]

      ts_utils.append("vlan:traffic", {ifid=ifstats.id, vlan=vlan_id,
                bytes_sent=vlan_stats["bytes.sent"], bytes_rcvd=vlan_stats["bytes.rcvd"]}, when, verbose)

      -- Save VLAN ndpi stats
      if vlan_stats["ndpi"] ~= nil then
        for proto_name, proto_stats in pairs(vlan_stats["ndpi"]) do
          ts_utils.append("vlan:ndpi", {ifid=ifstats.id, vlan=vlan_id, protocol=proto_name,
                    bytes_sent=proto_stats["bytes.sent"], bytes_rcvd=proto_stats["bytes.rcvd"]}, when, verbose)
        end
      end
    end
  end
end

-- ########################################################

function ts_dump.sflow_device_update_rrds(when, ifstats, verbose)
  local flowdevs = interface.getSFlowDevices()

  for flow_device_ip,_ in pairs(flowdevs) do
    local ports = interface.getSFlowDeviceInfo(flow_device_ip)

    if(verbose) then
      print ("["..__FILE__()..":"..__LINE__().."] Processing sFlow device "..flow_device_ip.."\n")
    end

    for port_idx,port_value in pairs(ports) do
      if ifstats.has_seen_ebpf_events then
        -- This is actualy an event exporter
        local dev_ifname = format_utils.formatExporterInterface(port_idx, port_value)

        ts_utils.append("evexporter_iface:traffic", {ifid=ifstats.id, exporter=flow_device_ip, ifname=dev_ifname,
                bytes_sent=port_value.ifOutOctets, bytes_rcvd=port_value.ifInOctets}, when, verbose)
      else
        ts_utils.append("sflowdev_port:traffic", {ifid=ifstats.id, device=flow_device_ip, port=port_idx,
                bytes_sent=port_value.ifOutOctets, bytes_rcvd=port_value.ifInOctets}, when, verbose)
      end
    end
  end
end

-- ########################################################

function ts_dump.flow_device_update_rrds(when, ifstats, verbose)
 local flowdevs = interface.getFlowDevices() -- Flow, not sFlow here

  for flow_device_ip,_ in pairs(flowdevs) do
    local ports = interface.getFlowDeviceInfo(flow_device_ip)

    if(verbose) then print ("["..__FILE__()..":"..__LINE__().."] Processing flow device "..flow_device_ip.."\n") end

    for port_idx,port_value in pairs(ports) do
      ts_utils.append("flowdev_port:traffic", {ifid=ifstats.id, device=flow_device_ip, port=port_idx,
                bytes_sent=port_value["bytes.out_bytes"], bytes_rcvd=port_value["bytes.in_bytes"]}, when, verbose)
    end
  end
end

-- ########################################################

function ts_dump.getConfig()
  local config = {}

  config.host_rrd_creation = ntop.getPref("ntopng.prefs.host_rrd_creation")
  config.host_ndpi_timeseries_creation = ntop.getPref("ntopng.prefs.host_ndpi_timeseries_creation")
  config.l2_device_rrd_creation = ntop.getPref("ntopng.prefs.l2_device_rrd_creation")
  config.l2_device_ndpi_timeseries_creation = ntop.getPref("ntopng.prefs.l2_device_ndpi_timeseries_creation")
  config.flow_devices_rrd_creation = ntop.getPref("ntopng.prefs.flow_device_port_rrd_creation")
  config.host_pools_rrd_creation = ntop.getPref("ntopng.prefs.host_pools_rrd_creation")
  config.snmp_devices_rrd_creation = ntop.getPref("ntopng.prefs.snmp_devices_rrd_creation")
  config.asn_rrd_creation = ntop.getPref("ntopng.prefs.asn_rrd_creation")
  config.country_rrd_creation = ntop.getPref("ntopng.prefs.country_rrd_creation")
  config.vlan_rrd_creation = ntop.getPref("ntopng.prefs.vlan_rrd_creation")
  config.tcp_retr_ooo_lost_rrd_creation = ntop.getPref("ntopng.prefs.tcp_retr_ooo_lost_rrd_creation")
  config.ndpi_flows_timeseries_creation = ntop.getPref("ntopng.prefs.ndpi_flows_rrd_creation")

  -- ########################################################
  -- Populate some defaults
  if(tostring(config.flow_devices_rrd_creation) == "1" and ntop.isEnterprise() == false) then
     config.flow_devices_rrd_creation = "0"
  end

  if(tostring(config.snmp_devices_rrd_creation) == "1" and ntop.isEnterprise() == false) then
     config.snmp_devices_rrd_creation = "0"
  end

  -- Local hosts RRD creation is on, with no nDPI rrd creation
  if isEmptyString(config.host_rrd_creation) then config.host_rrd_creation = "1" end
  if isEmptyString(config.host_ndpi_timeseries_creation) then config.host_ndpi_timeseries_creation = "none" end

  -- Devices RRD creation is OFF, as OFF is the nDPI rrd creation
  if isEmptyString(config.l2_device_rrd_creation) then config.l2_device_rrd_creation = "0" end
  if isEmptyString(config.l2_device_ndpi_timeseries_creation) then config.l2_device_ndpi_timeseries_creation = "none" end

  return config
end

-- ########################################################

function ts_dump.host_update_stats_rrds(when, hostname, host, ifstats, verbose)
  ts_utils.append("host:traffic", {ifid=ifstats.id, host=hostname,
            bytes_sent=host["bytes.sent"], bytes_rcvd=host["bytes.rcvd"]}, when, verbose)

  -- Number of flows
  ts_utils.append("host:active_flows", {ifid=ifstats.id, host=hostname,
				 flows_as_client = host["active_flows.as_client"],
				 flows_as_server = host["active_flows.as_server"]},
         when, verbose)
  ts_utils.append("host:total_flows", {ifid=ifstats.id, host=hostname,
				 flows_as_client = host["total_flows.as_client"],
				 flows_as_server = host["total_flows.as_server"]},
         when, verbose)

  -- Number of misbehaving flows
  ts_utils.append("host:misbehaving_flows", {ifid = ifstats.id, host = hostname,
					   flows_as_client = host["misbehaving_flows.as_client"],
					   flows_as_server = host["misbehaving_flows.as_server"]},
		  when, verbose)

  -- Number of unreachable flows
  ts_utils.append("host:unreachable_flows", {ifid = ifstats.id, host = hostname,
					   flows_as_client = host["unreachable_flows.as_client"],
					   flows_as_server = host["unreachable_flows.as_server"]},
      when, verbose)
    
  -- Number of host unreachable flows
  ts_utils.append("host:host_unreachable_flows", {ifid = ifstats.id, host = hostname,
            flows_as_server = host["host_unreachable_flows.as_server"],
            flows_as_client = host["host_unreachable_flows.as_client"]},
      when, verbose)

  -- Number of dns packets sent
  ts_utils.append("host:dns_qry_sent_rsp_rcvd", {ifid = ifstats.id, host = hostname,
            queries_packets = host["dns"]["sent"]["num_queries"],
            replies_ok_packets = host["dns"]["rcvd"]["num_replies_ok"],
            replies_error_packets =host["dns"]["rcvd"]["num_replies_error"]},
      when, verbose)

  -- Number of dns packets rcvd
  ts_utils.append("host:dns_qry_rcvd_rsp_sent", {ifid = ifstats.id, host = hostname,
            queries_packets = host["dns"]["rcvd"]["num_queries"],
            replies_ok_packets = host["dns"]["sent"]["num_replies_ok"],
            replies_error_packets = host["dns"]["sent"]["num_replies_error"]},
      when, verbose)

  if(host["icmp.echo_pkts_sent"] ~= nil) then
    ts_utils.append("host:echo_packets", {ifid = ifstats.id, host = hostname,
      packets_sent = host["icmp.echo_pkts_sent"],
      packets_rcvd = host["icmp.echo_pkts_rcvd"]},
      when, verbose)
  end

  if(host["icmp.echo_reply_pkts_sent"] ~= nil) then
    ts_utils.append("host:echo_reply_packets", {ifid = ifstats.id, host = hostname,
      packets_sent = host["icmp.echo_reply_pkts_sent"],
      packets_rcvd = host["icmp.echo_reply_pkts_rcvd"]},
      when, verbose)
  end
  
  -- Number of udp packets
  ts_utils.append("host:udp_pkts", {ifid = ifstats.id, host = hostname,
            packets_sent = host["udp.packets.sent"],
            packets_rcvd = host["udp.packets.rcvd"]},
      when, verbose)

  -- Tcp RX Stats 
  ts_utils.append("host:tcp_rx_stats", {ifid = ifstats.id, host = hostname,
            retransmission_packets = host["tcpPacketStats.rcvd"]["retransmissions"],
            out_of_order_packets = host["tcpPacketStats.rcvd"]["out_of_order"],
            lost_packets = host["tcpPacketStats.rcvd"]["lost"]},
      when, verbose)
  
  -- Tcp TX Stats
  ts_utils.append("host:tcp_tx_stats", {ifid = ifstats.id, host = hostname,
            retransmission_packets = host["tcpPacketStats.sent"]["retransmissions"],
            out_of_order_packets = host["tcpPacketStats.sent"]["out_of_order"],
            lost_packets = host["tcpPacketStats.sent"]["lost"]},
      when, verbose)
  
  -- Number of TCP packets
  ts_utils.append("host:tcp_packets", {ifid = ifstats.id, host = hostname,
            packets_sent = host["tcp.packets.sent"],
            packets_rcvd = host["tcp.packets.rcvd"]},
      when, verbose)

  -- Total number of alerts
  ts_utils.append("host:total_alerts", {ifid = ifstats.id, host = hostname,
					   alerts = host["total_alerts"]},
		  when, verbose)

  -- Total number of flow alerts
  ts_utils.append("host:total_flow_alerts", {ifid = ifstats.id, host = hostname,
					   alerts = host["num_flow_alerts"]},
		  when, verbose)

  -- Engaged alerts
  ts_utils.append("host:engaged_alerts", {ifid = ifstats.id, host = hostname,
					   alerts = host["engaged_alerts"]},
		  when, verbose)

  -- Contacts
  ts_utils.append("host:contacts", {ifid=ifstats.id, host=hostname,
            num_as_client=host["contacts.as_client"], num_as_server=host["contacts.as_server"]}, when, verbose)

  -- L4 Protocols
  for id, _ in pairs(l4_keys) do
    k = l4_keys[id][2]
    if((host[k..".bytes.sent"] ~= nil) and (host[k..".bytes.rcvd"] ~= nil)) then
      ts_utils.append("host:l4protos", {ifid=ifstats.id, host=hostname,
                l4proto=tostring(k), bytes_sent=host[k..".bytes.sent"], bytes_rcvd=host[k..".bytes.rcvd"]}, when, verbose)
    else
      -- L2 host
      --io.write("Discarding "..k.."@"..hostname.."\n")
    end
  end

  -- UDP breakdown
  ts_utils.append("host:udp_sent_unicast", {ifid=ifstats.id, host=hostname,
            bytes_sent_unicast=host["udpBytesSent.unicast"],
            bytes_sent_non_unicast=host["udpBytesSent.non_unicast"]}, when, verbose)

  -- create custom rrds
  if ts_custom and ts_custom.host_update_stats then
     ts_custom.host_update_stats(when, hostname, host, ifstats, verbose)
  end
end

function ts_dump.host_update_ndpi_rrds(when, hostname, host, ifstats, verbose, config)
  -- nDPI Protocols
  for k, value in pairs(host["ndpi"] or {}) do
    local sep = string.find(value, "|")
    local sep2 = string.find(value, "|", sep+1)
    local bytes_sent = string.sub(value, 1, sep-1)
    local bytes_rcvd = string.sub(value, sep+1, sep2-1)

    ts_utils.append("host:ndpi", {ifid=ifstats.id, host=hostname, protocol=k,
              bytes_sent=bytes_sent, bytes_rcvd=bytes_rcvd}, when, verbose)

    if config.ndpi_flows_timeseries_creation == "1" then
      local num_flows = string.sub(value, sep2+1)

      ts_utils.append("host:ndpi_flows", {ifid=ifstats.id, host=hostname, protocol=k,
              num_flows = num_flows}, when, verbose)
    end
  end
end

function ts_dump.host_update_categories_rrds(when, hostname, host, ifstats, verbose)
  -- nDPI Protocol CATEGORIES
  for k, value in pairs(host["ndpi_categories"] or {}) do
    local sep = string.find(value, "|")
    local bytes_sent = string.sub(value, 1, sep-1)
    local bytes_rcvd = string.sub(value, sep+1)
    
    ts_utils.append("host:ndpi_categories", {ifid=ifstats.id, host=hostname, category=k,
              bytes_sent=bytes_sent, bytes_rcvd=bytes_rcvd}, when, verbose)
  end
end

-- ########################################################

function ts_dump.host_update_rrd(when, hostname, host, ifstats, verbose, config)
  -- Crunch additional stats for local hosts only
  if config.host_rrd_creation ~= "0" then
    if enable_debug then
      traceError(TRACE_NORMAL, TRACE_CONSOLE, "@".. when .." Going to update host " .. hostname)
    end

    -- Traffic stats
    if(config.host_rrd_creation == "1") then
      ts_dump.host_update_stats_rrds(when, hostname, host, ifstats, verbose)
    end

    if(config.host_ndpi_timeseries_creation == "per_protocol" or config.host_ndpi_timeseries_creation == "both") then
      ts_dump.host_update_ndpi_rrds(when, hostname, host, ifstats, verbose, config)
    end

    if(config.host_ndpi_timeseries_creation == "per_category" or config.host_ndpi_timeseries_creation == "both") then
      ts_dump.host_update_categories_rrds(when, hostname, host, ifstats, verbose)
    end
  end
end

-- ########################################################

-- This performs all the 5 minutes tasks execept the timeseries dump
function ts_dump.run_5min_tasks(_ifname, ifstats)
  user_scripts.runPeriodicScripts("5mins")

  housekeepingAlertsMakeRoom(ifstats.id)
end

-- ########################################################

-- NOTE: this is executed every minute if ts_utils.hasHighResolutionTs() is true
function ts_dump.run_5min_dump(_ifname, ifstats, config, when, time_threshold, verbose)
  local is_rrd_creation_enabled = (ntop.getPref("ntopng.prefs.ifid_"..ifstats.id..".interface_rrd_creation") ~= "false")
  local num_processed_hosts = 0
  local min_instant = when - (when % 60) - 60

  local dump_tstart = os.time()
  local dumped_hosts = {}

  -- Save hosts stats (if enabled from the preferences)
  if is_rrd_creation_enabled and config.host_rrd_creation ~= "0" then
     local is_one_way_hosts_rrd_creation_enabled = (ntop.getPref("ntopng.prefs.ifid_"..ifstats.id..".interface_one_way_hosts_rrd_creation") ~= "false")

     local in_time = callback_utils.foreachLocalRRDHost(_ifname, time_threshold, true --[[ timeseries ]], is_one_way_hosts_rrd_creation_enabled, function (hostname, host_ts)
      local host_key = host_ts.tskey

      if(dumped_hosts[host_key] == nil) then
        local min_host_instant = min_instant

        if(host_ts.initial_point ~= nil) then
          -- Dump the first point
          if enable_debug then
            traceError(TRACE_NORMAL, TRACE_CONSOLE, "Dumping initial point for " .. host_key)
          end

          ts_dump.host_update_rrd(host_ts.initial_point_time, host_key, host_ts.initial_point, ifstats, verbose, config)
          min_host_instant = math.max(min_host_instant, host_ts.initial_point_time + 1)
        end

        host_ts = host_ts or {}

        if enable_debug then
          traceError(TRACE_NORMAL, TRACE_CONSOLE, "Dumping ".. (#host_ts) .." points for " .. host_key)
        end

        for _, host_point in ipairs(host_ts) do
          local instant = host_point.instant

          if instant >= min_host_instant then
            ts_dump.host_update_rrd(instant, host_key, host_point, ifstats, verbose, config)
          elseif enable_debug then
            traceError(TRACE_NORMAL, TRACE_CONSOLE, "Skipping point: instant=" .. instant .. " but min_host_instant=" .. min_host_instant)
          end
        end

        -- mark the host as dumped
        dumped_hosts[host_key] = true
      end

      num_processed_hosts = num_processed_hosts + 1
    end)

    if not in_time then
       traceError(TRACE_ERROR, TRACE_CONSOLE, "[".. _ifname .." ]" .. i18n("error_rrd_cannot_complete_dump"))
      return false
    end
  end

  --tprint("Dump of ".. num_processed_hosts .. " hosts: completed in " .. (os.time() - dump_tstart) .. " seconds")

  if is_rrd_creation_enabled then
    if config.l2_device_rrd_creation ~= "0" then
      local in_time = callback_utils.foreachDevice(_ifname, time_threshold, function (devicename, device)
        ts_dump.l2_device_update_stats_rrds(when, devicename, device, ifstats, verbose)

        if config.l2_device_ndpi_timeseries_creation == "per_category" then
          ts_dump.l2_device_update_categories_rrds(when, devicename, device, ifstats, verbose)
        end
      end)

      if not in_time then
        traceError(TRACE_ERROR, TRACE_CONSOLE, i18n("error_rrd_cannot_complete_dump"))
        return false
      end
    end

    -- create RRD for ASN
    if config.asn_rrd_creation == "1" then
      ts_dump.asn_update_rrds(when, ifstats, verbose)

      if config.tcp_retr_ooo_lost_rrd_creation == "1" then
        --[[ TODO: implement for ASes
        --]]
      end
    end

    -- create RRD for Countries
    if config.country_rrd_creation == "1" then
      ts_dump.country_update_rrds(when, ifstats, verbose)
    end

    -- Create RRD for vlans
    if config.vlan_rrd_creation == "1" then
      ts_dump.vlan_update_rrds(when, ifstats, verbose)

      if config.tcp_retr_ooo_lost_rrd_creation == "1" then
          --[[ TODO: implement for VLANs
          --]]
      end
    end

    -- Create RRDs for flow and sFlow devices
    if(config.flow_devices_rrd_creation == "1" and ntop.isEnterprise()) then
      ts_dump.sflow_device_update_rrds(when, ifstats, verbose)
      ts_dump.flow_device_update_rrds(when, ifstats, verbose)
    end

    -- Save Host Pools stats every 5 minutes
    if((ntop.isPro()) and (tostring(config.host_pools_rrd_creation) == "1")) then
      host_pools_utils.updateRRDs(ifstats.id, true --[[ also dump nDPI data ]], verbose)
    end
  end
end

-- ########################################################

return ts_dump
