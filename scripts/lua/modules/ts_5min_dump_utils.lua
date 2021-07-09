--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local graph_utils = require "graph_utils"
local alert_utils = require "alert_utils"
local host_pools = require "host_pools"
local host_pools_instance = host_pools:create()
local callback_utils = require "callback_utils"
local ts_utils = require "ts_utils_core"
local format_utils = require "format_utils"
local checks = require "checks"
require "ts_5min"

-- Set to true to debug host timeseries points timestamps
local enable_debug = false
local enable_behaviour_debug = false

if(ntop.getPref("ntopng.prefs.enable_anomaly_debug") == "1") then
   enable_behaviour_debug = true
end

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
              bytes=cat["bytes"]}, when)
  end
end

function ts_dump.l2_device_update_stats_rrds(when, devicename, device, ifstats, verbose)
  ts_utils.append("mac:traffic", {ifid=ifstats.id, mac=devicename,
              bytes_sent=device["bytes.sent"], bytes_rcvd=device["bytes.rcvd"]}, when, verbose)
  
  ts_utils.append("mac:arp_rqst_sent_rcvd_rpls", {ifid=ifstats.id, mac=devicename,
              request_packets_sent = device["arp_requests.sent"],
              reply_packets_rcvd = device["arp_replies.rcvd"]},
        when)
end

-- ########################################################

function ts_dump.subnet_update_rrds(when, ifstats, verbose)
  local subnet_stats = interface.getNetworksStats()

  for subnet,sstats in pairs(subnet_stats) do
    if ntop.isPro() then
      -- Check to see if the values are inserted
      if not sstats["score_behavior"] or 
          not sstats["traffic_rx_behavior"] or 
          not sstats["traffic_tx_behavior"] then
        goto continue
      end
      -- Score Behaviour
      ts_utils.append("subnet:score_behavior", 
      {ifid=ifstats.id, subnet=subnet,
      value=sstats["score_behavior"]["value"], 
      lower_bound=sstats["score_behavior"]["lower_bound"], 
      upper_bound = sstats["score_behavior"]["upper_bound"]}, when)
        
      -- Score Anomalies
      local anomaly = 0
      if sstats["score_behavior"]["anomaly"] == true then
        anomaly = 1
      end
        
      ts_utils.append("subnet:score_anomalies", 
      {ifid=ifstats.id, subnet=subnet, 
      anomaly=anomaly}, when)   

      -- Traffic Behaviour
      ts_utils.append("subnet:traffic_rx_behavior_v2", 
      {ifid=ifstats.id, subnet=subnet,
      value=sstats["traffic_rx_behavior"]["value"], 
      lower_bound = sstats["traffic_rx_behavior"]["lower_bound"], 
      upper_bound = sstats["traffic_rx_behavior"]["upper_bound"]}, when)

      ts_utils.append("subnet:traffic_tx_behavior_v2", 
      {ifid=ifstats.id, subnet=subnet,
      value=sstats["traffic_tx_behavior"]["value"], 
      lower_bound=sstats["traffic_tx_behavior"]["lower_bound"], 
      upper_bound = sstats["traffic_tx_behavior"]["upper_bound"]}, when)
        
      -- Traffic Anomalies
      local anomaly = 0
      if sstats["traffic_tx_behavior"]["anomaly"] == true or sstats["traffic_rx_behavior"]["anomaly"] == true then
        anomaly = 1
      end
        
      ts_utils.append("subnet:traffic_anomalies", 
      {ifid=ifstats.id, subnet=subnet, 
      anomaly=anomaly}, when)

    ::continue::
    end
  end
end

-- ########################################################

function ts_dump.iface_update_stats_rrds(when, ifstats, verbose)
  if ntop.isPro() then
    if not ifstats["score_behavior"] or 
        not ifstats["traffic_rx_behavior"] or 
        not ifstats["traffic_tx_behavior"] then
      goto continue
    end

    -- Score Behaviour
    ts_utils.append("iface:score_behavior", {ifid=ifstats.id,
      value=ifstats["score_behavior"]["value"], lower_bound=ifstats["score_behavior"]["lower_bound"], 
      upper_bound=ifstats["score_behavior"]["upper_bound"]}, when)
      
    -- Score Anomalies
    local anomaly = 0
    if ifstats["score_behavior"]["anomaly"] == true then
      anomaly = 1
    end
      
    ts_utils.append("iface:score_anomalies", {ifid=ifstats.id, anomaly=anomaly}, when)   

    -- Traffic Behaviour
    ts_utils.append("iface:traffic_rx_behavior_v2", {ifid=ifstats.id,
      value=ifstats["traffic_rx_behavior"]["value"], lower_bound=ifstats["traffic_rx_behavior"]["lower_bound"], 
      upper_bound=ifstats["traffic_rx_behavior"]["upper_bound"]}, when)

    ts_utils.append("iface:traffic_tx_behavior_v2", {ifid=ifstats.id,
      value=ifstats["traffic_tx_behavior"]["value"], lower_bound=ifstats["traffic_tx_behavior"]["lower_bound"], 
      upper_bound=ifstats["traffic_tx_behavior"]["upper_bound"]}, when)
      
    -- Traffic Anomalies
    local anomaly = 0
    if ifstats["traffic_tx_behavior"]["anomaly"] == true or ifstats["traffic_rx_behavior"]["anomaly"] == true then
      anomaly = 1
    end
      
    ts_utils.append("iface:traffic_anomalies", {ifid=ifstats.id, anomaly=anomaly}, when)   

  ::continue::
  end
end

-- ########################################################

function ts_dump.asn_update_rrds(when, ifstats, verbose)
  local asn_info = interface.getASesInfo({detailsLevel = "higher"})

  for _, asn_stats in pairs(asn_info["ASes"]) do
    local asn = asn_stats["asn"]

    -- Save ASN bytes
    ts_utils.append("asn:traffic", {ifid=ifstats.id, asn=asn,
				    bytes_sent=asn_stats["bytes.sent"], bytes_rcvd=asn_stats["bytes.rcvd"]}, when)

    ts_utils.append("asn:score",
		     {ifid=ifstats.id, asn=asn,
		      score=asn_stats["score"], scoreAsClient=asn_stats["score.as_client"], scoreAsServer=asn_stats["score.as_server"]}, when)


    ts_utils.append("asn:traffic_sent", {ifid=ifstats.id, asn=asn,
              bytes=asn_stats["bytes.sent"]}, when)

    ts_utils.append("asn:traffic_rcvd", {ifid=ifstats.id, asn=asn,
              bytes=asn_stats["bytes.rcvd"]}, when)
    -- Save ASN ndpi stats
    if asn_stats["ndpi"] ~= nil then
      for proto_name, proto_stats in pairs(asn_stats["ndpi"]) do
        ts_utils.append("asn:ndpi", {ifid=ifstats.id, asn=asn, protocol=proto_name,
                  bytes_sent=proto_stats["bytes.sent"], bytes_rcvd=proto_stats["bytes.rcvd"]}, when)
      end
    end

    -- Save ASN RTT stats
    ts_utils.append("asn:rtt",
		    {ifid=ifstats.id, asn=asn,
		     millis_rtt=asn_stats["round_trip_time"]}, when)

    -- Save ASN TCP stats
    if not ifstats.isSampledTraffic then
       ts_utils.append("asn:tcp_retransmissions",
		       {ifid=ifstats.id, asn=asn,
			packets_sent=asn_stats["tcpPacketStats.sent"]["retransmissions"],
			packets_rcvd=asn_stats["tcpPacketStats.rcvd"]["retransmissions"]}, when)

       ts_utils.append("asn:tcp_out_of_order",
		       {ifid=ifstats.id, asn=asn,
			packets_sent=asn_stats["tcpPacketStats.sent"]["out_of_order"],
			packets_rcvd=asn_stats["tcpPacketStats.rcvd"]["out_of_order"]}, when)

       ts_utils.append("asn:tcp_lost",
		       {ifid=ifstats.id, asn=asn,
			packets_sent=asn_stats["tcpPacketStats.sent"]["lost"],
			packets_rcvd=asn_stats["tcpPacketStats.rcvd"]["lost"]}, when)

       ts_utils.append("asn:tcp_keep_alive",
		       {ifid=ifstats.id, asn=asn,
			packets_sent=asn_stats["tcpPacketStats.sent"]["keep_alive"],
			packets_rcvd=asn_stats["tcpPacketStats.rcvd"]["keep_alive"]}, when)
    end

    if ntop.isPro() then
      -- Check to see if the values are inserted
      if not asn_stats["score_behavior"] or 
          not asn_stats["traffic_rx_behavior"] or 
          not asn_stats["traffic_tx_behavior"] then
        goto continue
      end
      -- Score Behaviour
      ts_utils.append("asn:score_behavior", 
      {ifid=ifstats.id, asn=asn,
      value=asn_stats["score_behavior"]["value"], 
      lower_bound=asn_stats["score_behavior"]["lower_bound"], 
      upper_bound = asn_stats["score_behavior"]["upper_bound"]}, when)
        
      -- Score Anomalies
      local anomaly = 0
      if asn_stats["score_behavior"]["anomaly"] == true then
        anomaly = 1
      end
        
      ts_utils.append("asn:score_anomalies", 
      {ifid=ifstats.id, asn=asn, 
      anomaly=anomaly}, when)   

      -- Traffic Behaviour
      ts_utils.append("asn:traffic_rx_behavior_v2", 
      {ifid=ifstats.id, asn=asn,
      value=asn_stats["traffic_rx_behavior"]["value"], 
      lower_bound=asn_stats["traffic_rx_behavior"]["lower_bound"], 
      upper_bound = asn_stats["traffic_rx_behavior"]["upper_bound"]}, when)

      ts_utils.append("asn:traffic_tx_behavior_v2", 
      {ifid=ifstats.id, asn=asn,
      value=asn_stats["traffic_tx_behavior"]["value"], 
      lower_bound=asn_stats["traffic_tx_behavior"]["lower_bound"], 
      upper_bound = asn_stats["traffic_tx_behavior"]["upper_bound"]}, when)
        
      -- Traffic Anomalies
      local anomaly = 0
      if asn_stats["traffic_tx_behavior"]["anomaly"] == true or asn_stats["traffic_rx_behavior"]["anomaly"] == true then
        anomaly = 1
      end
        
      ts_utils.append("asn:traffic_anomalies", 
      {ifid=ifstats.id, asn=asn, 
      anomaly=anomaly}, when)   

      ::continue::
    end
  end
end

-- ########################################################

function ts_dump.country_update_rrds(when, ifstats, verbose)
  local countries_info = interface.getCountriesInfo({detailsLevel = "higher", sortColumn = "column_country"})

  for _, country_stats in pairs(countries_info["Countries"] or {}) do
    local country = country_stats.country

    ts_utils.append("country:traffic", {ifid=ifstats.id, country=country,
                bytes_ingress=country_stats["ingress"], bytes_egress=country_stats["egress"],
                bytes_inner=country_stats["inner"]}, when)
   
    ts_utils.append("country:score",
		     {ifid=ifstats.id, country=country,
		      score=country_stats["score"], scoreAsClient=country_stats["score.as_client"], scoreAsServer=country_stats["score.as_server"]}, when)
  end
end

-- ########################################################

function ts_dump.os_update_rrds(when, ifstats, verbose)
  local os_info = interface.getOSesInfo()

  for _, os_stats in pairs(os_info["os"] or {}) do
    local OS = os_stats.os

    ts_utils.append("os:traffic", {ifid=ifstats.id, os=OS,
                bytes_ingress=os_stats["bytes.rcvd"], bytes_egress=os_stats["bytes.sent"]}, when)
  end
end

-- ########################################################

function ts_dump.vlan_update_rrds(when, ifstats, verbose)
  local vlan_info = interface.getVLANsInfo()

  if(vlan_info ~= nil) and (vlan_info["VLANs"] ~= nil) then
    for _, vlan_stats in pairs(vlan_info["VLANs"]) do
      local vlan_id = vlan_stats["vlan_id"]

      ts_utils.append("vlan:traffic", {ifid=ifstats.id, vlan=vlan_id,
				       bytes_sent=vlan_stats["bytes.sent"], bytes_rcvd=vlan_stats["bytes.rcvd"]}, when)

    ts_utils.append("vlan:score",
		     {ifid=ifstats.id, vlan=vlan_id,
		      score=vlan_stats["score"], scoreAsClient=vlan_stats["score.as_client"], scoreAsServer=vlan_stats["score.as_server"]}, when)

      -- Save VLAN ndpi stats
      if vlan_stats["ndpi"] ~= nil then
        for proto_name, proto_stats in pairs(vlan_stats["ndpi"]) do
          ts_utils.append("vlan:ndpi", {ifid=ifstats.id, vlan=vlan_id, protocol=proto_name,
                    bytes_sent=proto_stats["bytes.sent"], bytes_rcvd=proto_stats["bytes.rcvd"]}, when)
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
                bytes_sent=port_value.ifOutOctets, bytes_rcvd=port_value.ifInOctets}, when)
      else
        ts_utils.append("sflowdev_port:traffic", {ifid=ifstats.id, device=flow_device_ip, port=port_idx,
                bytes_sent=port_value.ifOutOctets, bytes_rcvd=port_value.ifInOctets}, when)
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
       -- Traffic
       ts_utils.append("flowdev_port:traffic",
		       {
			  ifid = ifstats.id, device = flow_device_ip, port = port_idx,
			  bytes_sent = port_value["bytes.out_bytes"], bytes_rcvd = port_value["bytes.in_bytes"]
		       },
		       when)

       -- nDPI
       for proto_name, proto_stats in pairs(port_value["ndpi"]) do
          ts_utils.append("flowdev_port:ndpi",
			  {
			     ifid = ifstats.id, device = flow_device_ip, port = port_idx, protocol = proto_name,
			     bytes_sent = proto_stats["bytes.sent"], bytes_rcvd = proto_stats["bytes.rcvd"]
			  },
			  when)
        end
    end
  end
end

-- ########################################################

function ts_dump.getConfig()
  local config = {}

  config.host_ts_creation = ntop.getPref("ntopng.prefs.hosts_ts_creation")
  config.host_ndpi_timeseries_creation = ntop.getPref("ntopng.prefs.host_ndpi_timeseries_creation")
  config.l2_device_rrd_creation = ntop.getPref("ntopng.prefs.l2_device_rrd_creation")
  config.l2_device_ndpi_timeseries_creation = ntop.getPref("ntopng.prefs.l2_device_ndpi_timeseries_creation")
  config.flow_devices_rrd_creation = ntop.getPref("ntopng.prefs.flow_device_port_rrd_creation")
  config.host_pools_rrd_creation = ntop.getPref("ntopng.prefs.host_pools_rrd_creation")
  config.snmp_devices_rrd_creation = ntop.getPref("ntopng.prefs.snmp_devices_rrd_creation")
  config.asn_rrd_creation = ntop.getPref("ntopng.prefs.asn_rrd_creation")
  config.country_rrd_creation = ntop.getPref("ntopng.prefs.country_rrd_creation")
  config.os_rrd_creation = ntop.getPref("ntopng.prefs.os_rrd_creation")
  config.vlan_rrd_creation = ntop.getPref("ntopng.prefs.vlan_rrd_creation")
  config.ndpi_flows_timeseries_creation = ntop.getPref("ntopng.prefs.ndpi_flows_rrd_creation")

  -- ########################################################
  -- Populate some defaults
  if(tostring(config.flow_devices_rrd_creation) == "1" and ntop.isEnterpriseM() == false) then
     config.flow_devices_rrd_creation = "0"
  end

  if(tostring(config.snmp_devices_rrd_creation) == "1" and ntop.isEnterpriseM() == false) then
     config.snmp_devices_rrd_creation = "0"
  end

  -- Local hosts RRD creation is on, with no nDPI rrd creation
  if isEmptyString(config.host_ts_creation) then config.host_ts_creation = "light" end
  if isEmptyString(config.host_ndpi_timeseries_creation) then config.host_ndpi_timeseries_creation = "none" end

  -- Devices RRD creation is OFF, as OFF is the nDPI rrd creation
  if isEmptyString(config.l2_device_rrd_creation) then config.l2_device_rrd_creation = "0" end
  if isEmptyString(config.l2_device_ndpi_timeseries_creation) then config.l2_device_ndpi_timeseries_creation = "none" end

  return config
end

-- ########################################################

function ts_dump.host_update_stats_rrds(when, hostname, host, ifstats, verbose)
   
  -- Number of flows
  if(host["active_flows.as_client"]) then
    ts_utils.append("host:active_flows", {ifid=ifstats.id, host=hostname,
				 flows_as_client = host["active_flows.as_client"],
				 flows_as_server = host["active_flows.as_server"]},
         when)
  end

  ts_utils.append("host:total_flows", {ifid=ifstats.id, host=hostname,
				 flows_as_client = host["total_flows.as_client"],
				 flows_as_server = host["total_flows.as_server"]},
         when)

  -- Number of alerted flows
  ts_utils.append("host:alerted_flows", {ifid = ifstats.id, host = hostname,
					   flows_as_client = host["alerted_flows.as_client"],
					   flows_as_server = host["alerted_flows.as_server"]},
		  when)

  -- Number of unreachable flows
  ts_utils.append("host:unreachable_flows", {ifid = ifstats.id, host = hostname,
					   flows_as_client = host["unreachable_flows.as_client"],
					   flows_as_server = host["unreachable_flows.as_server"]},
      when)
    
  -- Number of host unreachable flows
  ts_utils.append("host:host_unreachable_flows", {ifid = ifstats.id, host = hostname,
            flows_as_server = host["host_unreachable_flows.as_server"],
            flows_as_client = host["host_unreachable_flows.as_client"]},
      when)

  -- Number of dns packets sent
  ts_utils.append("host:dns_qry_sent_rsp_rcvd", {ifid = ifstats.id, host = hostname,
            queries_packets = host["dns"]["sent"]["num_queries"],
            replies_ok_packets = host["dns"]["rcvd"]["num_replies_ok"],
            replies_error_packets =host["dns"]["rcvd"]["num_replies_error"]},
      when)

  -- Number of dns packets rcvd
  ts_utils.append("host:dns_qry_rcvd_rsp_sent", {ifid = ifstats.id, host = hostname,
            queries_packets = host["dns"]["rcvd"]["num_queries"],
            replies_ok_packets = host["dns"]["sent"]["num_replies_ok"],
            replies_error_packets = host["dns"]["sent"]["num_replies_error"]},
      when)

  if(host["icmp.echo_pkts_sent"] ~= nil) then
    ts_utils.append("host:echo_packets", {ifid = ifstats.id, host = hostname,
      packets_sent = host["icmp.echo_pkts_sent"],
      packets_rcvd = host["icmp.echo_pkts_rcvd"]},
      when)
  end

  if(host["icmp.echo_reply_pkts_sent"] ~= nil) then
    ts_utils.append("host:echo_reply_packets", {ifid = ifstats.id, host = hostname,
      packets_sent = host["icmp.echo_reply_pkts_sent"],
      packets_rcvd = host["icmp.echo_reply_pkts_rcvd"]},
      when)
  end
  
  -- Number of udp packets
  ts_utils.append("host:udp_pkts", {ifid = ifstats.id, host = hostname,
            packets_sent = host["udp.packets.sent"],
            packets_rcvd = host["udp.packets.rcvd"]},
      when)

  -- Tcp RX Stats 
  ts_utils.append("host:tcp_rx_stats", {ifid = ifstats.id, host = hostname,
            retransmission_packets = host["tcpPacketStats.rcvd"]["retransmissions"],
            out_of_order_packets = host["tcpPacketStats.rcvd"]["out_of_order"],
            lost_packets = host["tcpPacketStats.rcvd"]["lost"]},
      when)
  
  -- Tcp TX Stats
  ts_utils.append("host:tcp_tx_stats", {ifid = ifstats.id, host = hostname,
            retransmission_packets = host["tcpPacketStats.sent"]["retransmissions"],
            out_of_order_packets = host["tcpPacketStats.sent"]["out_of_order"],
            lost_packets = host["tcpPacketStats.sent"]["lost"]},
      when)
  
  -- Number of TCP packets
  ts_utils.append("host:tcp_packets", {ifid = ifstats.id, host = hostname,
            packets_sent = host["tcp.packets.sent"],
            packets_rcvd = host["tcp.packets.rcvd"]},
      when)

  -- Total number of alerts
  ts_utils.append("host:total_alerts", {ifid = ifstats.id, host = hostname,
					alerts = host["total_alerts"]},
		  when)

  -- Engaged alerts
  if host["engaged_alerts"] then
    ts_utils.append("host:engaged_alerts", {ifid = ifstats.id, host = hostname,
					   alerts = host["engaged_alerts"]},
		  when)
  end

  -- Contacts
  if host["contacts.as_client"] then
    ts_utils.append("host:contacts", {ifid=ifstats.id, host=hostname,
            num_as_client=host["contacts.as_client"], num_as_server=host["contacts.as_server"]}, when)
  end

  if enable_debug then
     io.write(hostname.. "\n")
  end

  if(host.num_blacklisted_flows ~= nil) then
     -- Note: tot_as_* are never resetted, instead the other counters can be resetted
     ts_utils.append("host:num_blacklisted_flows", {ifid=ifstats.id, host=hostname,
						    flows_as_client = host.num_blacklisted_flows.tot_as_client,
						    flows_as_server = host.num_blacklisted_flows.tot_as_server},
		     when)
  end
  
  -- Contacted Hosts Behaviour
  if host["contacted_hosts_behaviour"] then
     if(host.contacted_hosts_behaviour.value > 0) then
	local lower = host.contacted_hosts_behaviour.lower_bound
	local upper = host.contacted_hosts_behaviour.upper_bound
	local value = host.contacted_hosts_behaviour.value
	local initialRun

	if(not(initialRun) and ((value < lower) or (value > upper))) then
	   rsp = "ANOMALY"
	else
	   rsp = "OK"
	end

	if enable_behaviour_debug then
	   io.write(hostname.."\n\t\t[Contacts Behaviour]\n\t\t[value: "..tostring(value).."][lower: "..tostring(lower).."][upper: "..tostring(upper).."]["..rsp.."]\n");
	end
     end
     
    ts_utils.append("host:contacts_behaviour", {ifid=ifstats.id, host=hostname,
						value=(host.contacted_hosts_behaviour.value or 0), lower_bound=(host.contacted_hosts_behaviour.lower_bound or 0), upper_bound = (host.contacted_hosts_behaviour.upper_bound or 0)}, when)
  end

  if host["score_behaviour"] then
     local h = host["score_behaviour"]

     if enable_behaviour_debug then
	if(h["as_client"]["anomaly"]) then rsp = "ANOMALY" else rsp = "OK" end
	io.write(hostname.."\n\t\t[Score Behaviour]\n\t\t\t[Client][value: "..tostring(h["as_client"]["value"]).."]lower: "..tostring(h["as_client"]["lower_bound"]).."][upper: "..tostring(h["as_client"]["upper_bound"]).."]["..rsp.."]\n")
	
	if(h["as_server"]["anomaly"]) then rsp = "ANOMALY" else rsp = "OK" end
	io.write("\t\t\t[Server][value: "..tostring(h["as_server"]["value"]).."][lower: "..tostring(h["as_server"]["lower_bound"]).."][upper: "..tostring(h["as_server"]["upper_bound"]).."]["..rsp.."]\n")
     end

     -- Score Behaviour
     --tprint(h)
     ts_utils.append("host:cli_score_behaviour", {ifid=ifstats.id, host=hostname,
						  value=h["as_client"]["value"], lower_bound=h["as_client"]["lower_bound"], upper_bound = h["as_client"]["upper_bound"]}, when)
     ts_utils.append("host:srv_score_behaviour", {ifid=ifstats.id, host=hostname,
						  value=h["as_server"]["value"], lower_bound=h["as_server"]["lower_bound"], upper_bound = h["as_server"]["upper_bound"]}, when)
     
     -- Score Anomalies
     local cli_anomaly = 0
     local srv_anomaly = 0
     if h["as_client"]["anomaly"] == true then
	cli_anomaly = 1
     end
     if h["as_server"]["anomaly"] == true then
	srv_anomaly = 1
     end
     
     ts_utils.append("host:cli_score_anomalies", {ifid=ifstats.id, host=hostname, anomaly=cli_anomaly}, when)     
     ts_utils.append("host:srv_score_anomalies", {ifid=ifstats.id, host=hostname, anomaly=srv_anomaly}, when)
  end
  

  -- Active Flows Behaviour
  if host["active_flows_behaviour"] then
     local h = host["active_flows_behaviour"]

     if enable_behaviour_debug then
	if(h["as_client"]["anomaly"]) then rsp = "ANOMALY" else rsp = "OK" end
	io.write("\n\t\t[Active Flows Behaviour]\n\t\t\t[Client][value: "..tostring(h["as_client"]["value"]).."][lower: "..tostring(h["as_client"]["lower_bound"]).."][upper: "..tostring(h["as_client"]["upper_bound"]).."]["..rsp.."]\n");
	if(h["as_server"]["anomaly"]) then rsp = "ANOMALY" else rsp = "OK" end
	io.write("\t\t\t[Server][value: "..tostring(h["as_server"]["value"]).."][lower: "..tostring(h["as_server"]["lower_bound"]).."][upper: "..tostring(h["as_server"]["upper_bound"]).."]["..rsp.."]\n");
     end

     --tprint(h)
     ts_utils.append("host:cli_active_flows_behaviour", {ifid=ifstats.id, host=hostname,
							 value=h["as_client"]["value"], lower_bound=h["as_client"]["lower_bound"], upper_bound = h["as_client"]["upper_bound"]}, when)
     ts_utils.append("host:srv_active_flows_behaviour", {ifid=ifstats.id, host=hostname,
							 value=h["as_server"]["value"], lower_bound=h["as_server"]["lower_bound"], upper_bound = h["as_server"]["upper_bound"]}, when)

     -- Active Flows Anomalies
     local cli_anomaly = 0
     local srv_anomaly = 0
     if h["as_client"]["anomaly"] == true then
	cli_anomaly = 1
     end
     if h["as_server"]["anomaly"] == true then
	srv_anomaly = 1
     end
     
     ts_utils.append("host:cli_active_flows_anomalies", {ifid=ifstats.id, host=hostname,
						  anomaly=cli_anomaly}, when)
     
     ts_utils.append("host:srv_active_flows_anomalies", {ifid=ifstats.id, host=hostname,
						  anomaly=srv_anomaly}, when)
  end
  enable_debug = false

  -- L4 Protocols
  for id, _ in pairs(l4_keys) do
    k = l4_keys[id][2]
    if((host[k..".bytes.sent"] ~= nil) and (host[k..".bytes.rcvd"] ~= nil)) then
      ts_utils.append("host:l4protos", {ifid=ifstats.id, host=hostname,
                l4proto=tostring(k), bytes_sent=host[k..".bytes.sent"], bytes_rcvd=host[k..".bytes.rcvd"]}, when)
    else
      -- L2 host
      --io.write("Discarding "..k.."@"..hostname.."\n")
    end
  end

  -- DSCP Classes
  for id, value in pairs(host.dscp) do
    if value["bytes.sent"] ~= nil and value["bytes.rcvd"] ~= nil then
      ts_utils.append("host:dscp",
        {
          ifid=ifstats.id,
          host=hostname,
          dscp_class=id,
          bytes_sent=value["bytes.sent"],
          bytes_rcvd=value["bytes.rcvd"]
        },
        when)
    end
  end

  -- UDP breakdown
  ts_utils.append("host:udp_sent_unicast", {ifid=ifstats.id, host=hostname,
            bytes_sent_unicast=host["udpBytesSent.unicast"],
            bytes_sent_non_unicast=host["udpBytesSent.non_unicast"]}, when)

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
              bytes_sent=bytes_sent, bytes_rcvd=bytes_rcvd}, when)

    if config.ndpi_flows_timeseries_creation == "1" then
      local num_flows = string.sub(value, sep2+1)

      ts_utils.append("host:ndpi_flows", {ifid=ifstats.id, host=hostname, protocol=k,
              num_flows = num_flows}, when)
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
              bytes_sent=bytes_sent, bytes_rcvd=bytes_rcvd}, when)
  end
end

-- ########################################################

function ts_dump.host_update_rrd(when, hostname, host, ifstats, verbose, config)
  -- Crunch additional stats for local hosts only
  if config.host_ts_creation ~= "off" then
    if enable_debug then
      traceError(TRACE_NORMAL, TRACE_CONSOLE, "@".. when .." Going to update host " .. hostname)
    end

    -- Traffic stats
    ts_utils.append("host:traffic", {ifid=ifstats.id, host=hostname,
				     bytes_sent=host["bytes.sent"], bytes_rcvd=host["bytes.rcvd"]}, when)

    -- Score
    ts_utils.append("host:score", {ifid=ifstats.id, host=hostname, score_as_cli = host["score.as_client"], score_as_srv = host["score.as_server"]}, when)

    if(config.host_ts_creation == "full") then
      ts_dump.host_update_stats_rrds(when, hostname, host, ifstats, verbose)

      if(config.host_ndpi_timeseries_creation == "per_protocol" or config.host_ndpi_timeseries_creation == "both") then
        ts_dump.host_update_ndpi_rrds(when, hostname, host, ifstats, verbose, config)
      end

      if(config.host_ndpi_timeseries_creation == "per_category" or config.host_ndpi_timeseries_creation == "both") then
        ts_dump.host_update_categories_rrds(when, hostname, host, ifstats, verbose)
      end
    end
  end
end

-- ########################################################

-- This performs all the 5 minutes tasks execept the timeseries dump
function ts_dump.run_5min_tasks(_ifname, ifstats)
  checks.schedulePeriodicScripts("5mins")
end

-- ########################################################

-- NOTE: this is executed every minute if ts_utils.hasHighResolutionTs() is true
function ts_dump.run_5min_dump(_ifname, ifstats, config, when)
  local num_processed_hosts = 0
  local min_instant = when - (when % 60) - 60

  local dump_tstart = os.time()
  local dumped_hosts = {}

  -- Save hosts stats (if enabled from the preferences)
  if config.host_ts_creation ~= "off" then
     local is_one_way_hosts_rrd_creation_enabled = (ntop.getPref("ntopng.prefs.hosts_one_way_traffic_rrd_creation") == "1")

     local in_time = callback_utils.foreachLocalRRDHost(_ifname, true --[[ timeseries ]], is_one_way_hosts_rrd_creation_enabled, function (hostname, host_ts)
      local host_key = host_ts.tskey

      if(dumped_hosts[host_key] == nil) then
        if(host_ts.initial_point ~= nil) then
          -- Dump the first point
          if enable_debug then
            traceError(TRACE_NORMAL, TRACE_CONSOLE, "Dumping initial point for " .. host_key)
          end

          ts_dump.host_update_rrd(host_ts.initial_point_time, host_key, host_ts.initial_point, ifstats, verbose, config)
        end

        ts_dump.host_update_rrd(when, host_key, host_ts.ts_point, ifstats, verbose, config)

        -- mark the host as dumped
        dumped_hosts[host_key] = true
      end

      if((num_processed_hosts % 64) == 0) then
        if not ntop.isDeadlineApproaching() then
          local num_local = interface.getNumLocalHosts() -- note: may be changed

          interface.setPeriodicActivityProgress(num_processed_hosts * 100 / num_local)
        end
      end

      num_processed_hosts = num_processed_hosts + 1
    end)

    if not in_time then
       traceError(TRACE_ERROR, TRACE_CONSOLE, "[".. _ifname .."]" .. i18n("error_rrd_cannot_complete_dump"))
      return false
    end

    if(in_time and (not ntop.isDeadlineApproaching())) then
      -- Here we assume that all the writes have completed successfully
      interface.setPeriodicActivityProgress(100)
    end
  end

  --tprint("Dump of ".. num_processed_hosts .. " hosts: completed in " .. (os.time() - dump_tstart) .. " seconds")

  if config.l2_device_rrd_creation ~= "0" then
    local in_time = callback_utils.foreachDevice(_ifname, function (devicename, device)
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
  end

  -- Update 5min Network stats
  ts_dump.subnet_update_rrds(when, ifstats, verbose)

  -- Update 5min Network stats
  ts_dump.iface_update_stats_rrds(when, ifstats, verbose)

  -- create RRD for Countries
  if config.country_rrd_creation == "1" then
    ts_dump.country_update_rrds(when, ifstats, verbose)
  end

  -- create RRD for OSes
  if config.os_rrd_creation == "1" then
    ts_dump.os_update_rrds(when, ifstats, verbose)
  end
  
  -- Create RRD for vlans
  if config.vlan_rrd_creation == "1" then
    ts_dump.vlan_update_rrds(when, ifstats, verbose)
  end

  -- Create RRDs for flow and sFlow devices
  if(config.flow_devices_rrd_creation == "1" and ntop.isEnterpriseM()) then
    ts_dump.sflow_device_update_rrds(when, ifstats, verbose)
    ts_dump.flow_device_update_rrds(when, ifstats, verbose)
  end

  -- Save Host Pools stats every 5 minutes
  if((ntop.isPro()) and (tostring(config.host_pools_rrd_creation) == "1")) then
    host_pools_instance:updateRRDs(ifstats.id, true --[[ also dump nDPI data ]], verbose)
  end
end

-- ########################################################

return ts_dump
