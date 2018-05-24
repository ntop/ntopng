require "lua_utils"
require "graph_utils"
require "alert_utils"
require "rrd_utils"
local host_pools_utils = require "host_pools_utils"
local callback_utils = require "callback_utils"
local os_utils = require "os_utils"
local ts_utils = require "ts_utils"
local ts_schemas = require "ts_schemas"

local dirs = ntop.getDirs()
local rrd_dump = {}

-- ########################################################

function rrd_dump.host_update_stats_rrds(when, hostname, hostbase, host, ifstats, verbose)
  ts_utils.append(ts_schemas.host_traffic(), {ifid=ifstats.id, host=hostname,
            bytes_sent=host["bytes.sent"], bytes_rcvd=host["bytes.rcvd"]}, when, verbose)
  ntop.tsSet(when, 'ip', hostname, "bytes", tolongint(host["bytes.sent"]), tolongint(host["bytes.rcvd"]))

  -- Number of flows
  ts_utils.append(ts_schemas.host_flows(), {ifid=ifstats.id, host=hostname,
            num_flows=host["active_flows.as_client"] + host["active_flows.as_server"]}, when, verbose)

  -- L4 Protocols
  for id, _ in ipairs(l4_keys) do
    k = l4_keys[id][2]
    if((host[k..".bytes.sent"] ~= nil) and (host[k..".bytes.rcvd"] ~= nil)) then
      ts_utils.append(ts_schemas.host_l4protos(), {ifid=ifstats.id, host=hostname,
                l4proto=tostring(k), bytes_sent=host[k..".bytes.sent"], bytes_rcvd=host[k..".bytes.rcvd"]}, when, verbose)

      ntop.tsSet(when, 'ip', hostname, tostring(k), tolongint(host[k..".bytes.sent"]), tolongint(host[k..".bytes.rcvd"]), when)
    else
      -- L2 host
      --io.write("Discarding "..k.."@"..hostname.."\n")
    end
  end
end

function rrd_dump.host_update_ndpi_rrds(when, hostname, hostbase, host, ifstats, verbose)
  -- nDPI Protocols
  for k in pairs(host["ndpi"] or {}) do
    ts_utils.append(ts_schemas.host_ndpi(), {ifid=ifstats.id, host=hostname, protocol=k,
              bytes_sent=host["ndpi"][k]["bytes.sent"], bytes_rcvd=host["ndpi"][k]["bytes.rcvd"]}, when, verbose)

    ntop.tsSet(when, 'ip:ndpi', hostname, tostring(k),
              tolongint(host["ndpi"][k]["bytes.sent"]), tolongint(host["ndpi"][k]["bytes.rcvd"]))
  end
end

function rrd_dump.host_update_categories_rrds(when, hostname, hostbase, host, ifstats, verbose)
  -- nDPI Protocol CATEGORIES
  for k, cat in pairs(host["ndpi_categories"] or {}) do
    ts_utils.append(ts_schemas.host_ndpi_categories(), {ifid=ifstats.id, host=hostname, category=k,
              bytes=cat["bytes"]}, when, verbose)

    ntop.tsSet(when, 'ip:ndpi_categories', hostname, tostring(k), tolongint(cat["bytes"]), 0)
  end
end

-- ########################################################

function rrd_dump.l2_device_update_categories_rrds(when, devicename, device, devicebase, ifstats, verbose)
  -- nDPI Protocol CATEGORIES
  for k, cat in pairs(device["ndpi_categories"] or {}) do
    ts_utils.append(ts_schemas.mac_ndpi_categories(), {ifid=ifstats.id, mac=devicename, category=k,
              bytes=cat["bytes"]}, when, verbose)
    ntop.tsSet(when, 'mac:ndpi_categories', devicename, k, tolongint(cat["bytes"]), 0)
  end
end

function rrd_dump.l2_device_update_stats_rrds(when, devicename, device, devicebase, ifstats, verbose)
  ts_utils.append(ts_schemas.mac_traffic(), {ifid=ifstats.id, mac=devicename,
              bytes_sent=device["bytes.sent"], bytes_rcvd=device["bytes.rcvd"]}, when, verbose)
  ntop.tsSet(when, 'mac', devicename, "bytes", tolongint(device["bytes.sent"]), tolongint(device["bytes.rcvd"]))
end

-- ########################################################

function rrd_dump.asn_update_rrds(when, ifstats, verbose)
  local asn_info = interface.getASesInfo({detailsLevel = "higher"})

  for _, asn_stats in ipairs(asn_info["ASes"]) do
    local asn = asn_stats["asn"]

    -- Save ASN bytes
    ts_utils.append(ts_schemas.asn_traffic(), {ifid=ifstats.id, asn=asn,
              bytes_sent=asn_stats["bytes.sent"], bytes_rcvd=asn_stats["bytes.rcvd"]}, when)
    ntop.tsSet(when, 'asn', tostring(asn), "bytes",
              tolongint(asn_stats["bytes.sent"]), tolongint(asn_stats["bytes.rcvd"]))

    -- Save ASN ndpi stats
    if asn_stats["ndpi"] ~= nil then
      for proto_name, proto_stats in pairs(asn_stats["ndpi"]) do
        ts_utils.append(ts_schemas.asn_ndpi(), {ifid=ifstats.id, asn=asn, protocol=proto_name,
                  bytes_sent=proto_stats["bytes.sent"], bytes_rcvd=proto_stats["bytes.rcvd"]}, when, verbose)
        ntop.tsSet(when, 'asn:ndpi', tostring(asn), proto_name,
                  tolongint(proto_stats["bytes.sent"]), tolongint(proto_stats["bytes.rcvd"]))
      end
    end

    -- Save ASN RTT stats
    ts_utils.append(ts_schemas.asn_rtt(), {ifid=ifstats.id, asn=asn,
                millis_rtt=asn_stats["round_trip_time"]}, when, verbose)
  end
end

-- ########################################################

function rrd_dump.country_update_rrds(when, ifstats, verbose)
  local basedir = os_utils.fixPath(dirs.workingdir .. "/" .. ifstats.id..'/countrystats')
  local countries_info = interface.getCountriesInfo({detailsLevel = "higher", sortColumn = "column_country"})

  for _, country_stats in ipairs(countries_info["Countries"] or {}) do
    local country = country_stats.country

    ts_utils.append(ts_schemas.country_traffic(), {ifid=ifstats.id, country=country,
                bytes_ingress=country_stats["ingress"], bytes_egress=country_stats["egress"],
                bytes_inner=country_stats["inner"]}, when, verbose)
    ntop.tsSet(when, "iface:countrystats", country, "bytes", tolongint(country_stats["egress"]), tolongint(country_stats["inner"]))
  end
end

-- ########################################################

function rrd_dump.vlan_update_rrds(when, ifstats, verbose)
  local basedir = os_utils.fixPath(dirs.workingdir .. "/" .. ifstats.id..'/vlanstats')
  local vlan_info = interface.getVLANsInfo()

  if(vlan_info ~= nil) and (vlan_info["VLANs"] ~= nil) then
    for _, vlan_stats in pairs(vlan_info["VLANs"]) do
      local vlan_id = vlan_stats["vlan_id"]

      ts_utils.append(ts_schemas.vlan_traffic(), {ifid=ifstats.id, vlan=vlan_id,
                bytes_sent=vlan_stats["bytes.sent"], bytes_rcvd=vlan_stats["bytes.rcvd"]}, when, verbose)

      ntop.tsSet(when, 'vlan', tostring(vlan_id), "bytes",
                tolongint(vlan_stats["bytes.sent"]), tolongint(vlan_stats["bytes.rcvd"]))

      -- Save VLAN ndpi stats
      if vlan_stats["ndpi"] ~= nil then
        for proto_name, proto_stats in pairs(vlan_stats["ndpi"]) do
          ts_utils.append(ts_schemas.vlan_ndpi(), {ifid=ifstats.id, vlan=vlan_id, protocol=proto_name,
                    bytes_sent=proto_stats["bytes.sent"], bytes_rcvd=proto_stats["bytes.rcvd"]}, when, verbose)
          
          ntop.tsSet(when, 'vlan:ndpi', tostring(vlan_id), proto_name,
            tolongint(proto_stats["bytes.sent"]), tolongint(proto_stats["bytes.rcvd"]))
        end
      end
    end
  end
end

-- ########################################################

function rrd_dump.sflow_device_update_rrds(when, ifstats, verbose)
  local flowdevs = interface.getSFlowDevices()

  for flow_device_ip,_ in pairs(flowdevs) do
    local ports = interface.getSFlowDeviceInfo(flow_device_ip)

    if(verbose) then
      print ("["..__FILE__()..":"..__LINE__().."] Processing sFlow device "..flow_device_ip.."\n")
    end

    for port_idx,port_value in pairs(ports) do
      ts_utils.append(ts_schemas.sflowdev_port_traffic(), {ifid=ifstats.id, device=flow_device_ip, port=port_idx,
                bytes_sent=port_value.ifOutOctets, bytes_rcvd=port_value.ifInOctets}, when, verbose)

      ntop.tsSet(when, "sflow", flow_device_ip, "bytes",
        tolongint(port_value.ifOutOctets), tolongint(port_value.ifInOctets))
    end
  end
end

-- ########################################################

function rrd_dump.flow_device_update_rrds(when, ifstats, verbose)
 local flowdevs = interface.getFlowDevices() -- Flow, not sFlow here

  for flow_device_ip,_ in pairs(flowdevs) do
    local ports = interface.getFlowDeviceInfo(flow_device_ip)

    if(verbose) then print ("["..__FILE__()..":"..__LINE__().."] Processing flow device "..flow_device_ip.."\n") end

    for port_idx,port_value in pairs(ports) do
      ts_utils.append(ts_schemas.flowdev_port_traffic(), {ifid=ifstats.id, device=flow_device_ip, port=port_idx,
                bytes_sent=port_value["bytes.out_bytes"], bytes_rcvd=port_value["bytes.in_bytes"]}, when, verbose)

      ntop.tsSet(when, "flow_device", flow_device_ip, "bytes",
          tolongint(port_value["bytes.out_bytes"]), tolongint(port_value["bytes.in_bytes"]))
    end
  end
end

-- ########################################################

function rrd_dump.getConfig()
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

function rrd_dump.run_5min_dump(_ifname, ifstats, config, when, time_threshold, verbose)
  local working_status = nil
  local is_rrd_creation_enabled = interface_rrd_creation_enabled(ifstats.id)
  local are_alerts_enabled = mustScanAlerts(ifstats)

  -- alerts stuff
  if are_alerts_enabled then
    housekeepingAlertsMakeRoom(getInterfaceId(_ifname))
    working_status = newAlertsWorkingStatus(ifstats, "5mins")

    check_interface_alerts(ifstats.id, working_status)
    check_networks_alerts(ifstats.id, working_status)
    -- will scan the hosts alerts below
  end

  -- Save hosts stats (if enabled from the preferences)
  if is_rrd_creation_enabled or are_alerts_enabled then
    local in_time = callback_utils.foreachLocalRRDHost(_ifname, time_threshold, function (hostname, host, hostbase)
      if are_alerts_enabled then
        -- Check alerts first
        check_host_alerts(ifstats.id, working_status, hostname)
      end

      if is_rrd_creation_enabled then
        -- Crunch additional stats for local hosts only
        if config.host_rrd_creation ~= "0" then
          -- Traffic stats
          if(config.host_rrd_creation == "1") then
            rrd_dump.host_update_stats_rrds(when, hostname, hostbase, host, ifstats, verbose)
          end

          if(config.host_ndpi_timeseries_creation == "per_protocol" or config.host_ndpi_timeseries_creation == "both") then
            rrd_dump.host_update_ndpi_rrds(when, hostname, hostbase, host, ifstats, verbose)
          end

          if(config.host_ndpi_timeseries_creation == "per_category" or config.host_ndpi_timeseries_creation == "both") then
            rrd_dump.host_update_categories_rrds(when, hostname, hostbase, host, ifstats, verbose)
          end
        end
      end
    end)

    if working_status ~= nil then
      -- NOTE: must always finalize current working_status before returning
      finalizeAlertsWorkingStatus(working_status)
    end

    if not in_time then
       traceError(TRACE_ERROR, TRACE_CONSOLE, "[".. _ifname .." ]" .. i18n("error_rrd_cannot_complete_dump"))
      return false
    end
  end

  if is_rrd_creation_enabled then
    if config.l2_device_rrd_creation ~= "0" then
      local in_time = callback_utils.foreachDevice(_ifname, time_threshold, function (devicename, device, devicebase)
        rrd_dump.l2_device_update_stats_rrds(when, devicename, device, devicebase, ifstats, verbose)

        if config.l2_device_ndpi_timeseries_creation == "per_category" then
          rrd_dump.l2_device_update_categories_rrds(when, devicename, device, devicebase, ifstats, verbose)
        end
      end)

      if not in_time then
        traceError(TRACE_ERROR, TRACE_CONSOLE, i18n("error_rrd_cannot_complete_dump"))
        return false
      end
    end

    -- create RRD for ASN
    if config.asn_rrd_creation == "1" then
      rrd_dump.asn_update_rrds(when, ifstats, verbose)

      if config.tcp_retr_ooo_lost_rrd_creation == "1" then
        --[[ TODO: implement for ASes
        --]]
      end
    end

    -- create RRD for Countries
    if config.country_rrd_creation == "1" then
      rrd_dump.country_update_rrds(when, ifstats, verbose)
    end

    -- Create RRD for vlans
    if config.vlan_rrd_creation == "1" then
      rrd_dump.vlan_update_rrds(when, ifstats, verbose)

      if config.tcp_retr_ooo_lost_rrd_creation == "1" then
          --[[ TODO: implement for VLANs
          --]]
      end
    end

    -- Create RRDs for flow and sFlow devices
    if(config.flow_devices_rrd_creation == "1" and ntop.isEnterprise()) then
      rrd_dump.sflow_device_update_rrds(when, ifstats, verbose)
      rrd_dump.flow_device_update_rrds(when, ifstats, verbose)
    end

    -- Save Host Pools stats every 5 minutes
    if((ntop.isPro()) and (tostring(config.host_pools_rrd_creation) == "1") and (not ifstats.isView)) then
      host_pools_utils.updateRRDs(ifstats.id, true --[[ also dump nDPI data ]], verbose)
    end
  end
end

-- ########################################################

return rrd_dump
