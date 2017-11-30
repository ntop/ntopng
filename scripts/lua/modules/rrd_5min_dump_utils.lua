require "lua_utils"
require "graph_utils"
require "alert_utils"
local rrd_utils = require "rrd_utils"
local host_pools_utils = require "host_pools_utils"
local callback_utils = require "callback_utils"
local os_utils = require "os_utils"

local dirs = ntop.getDirs()
local rrd_dump = {}

-- ########################################################

function rrd_dump.iface_update_ndpi_rrds(when, basedir, _ifname, ifstats, verbose)
  for k in pairs(ifstats["ndpi"]) do
    local v = ifstats["ndpi"][k]["bytes.sent"]+ifstats["ndpi"][k]["bytes.rcvd"]
    if(verbose) then print("["..__FILE__()..":"..__LINE__().."] ".._ifname..": "..k.."="..v.."\n") end

    local name = os_utils.fixPath(basedir .. "/"..k..".rrd")
    createSingleRRDcounter(name, 300, verbose)
    ntop.rrd_update(name, nil, tolongint(v))
    ntop.tsSet(when, ifstats.id, 300, 'iface:ndpi', tostring(k), "bytes", ifstats["ndpi"][k]["bytes.sent"], ifstats["ndpi"][k]["bytes.rcvd"])
    end
end

function rrd_dump.iface_update_categories_rrds(when, basedir, _ifname, ifstats, verbose)
  for k, v in pairs(ifstats["ndpi_categories"]) do
    v = v["bytes"]
    if(verbose) then print("["..__FILE__()..":"..__LINE__().."] ".._ifname..": "..k.."="..v.."\n") end

    local name = os_utils.fixPath(basedir .. "/"..k..".rrd")
    createSingleRRDcounter(name, 300, verbose)
    ntop.rrd_update(name, nil, tolongint(v))
    ntop.tsSet(when, ifstats.id, 300, 'iface:ndpi_categories', tostring(k), "bytes", v, 0)
  end
end

function rrd_dump.iface_update_stats_rrds(when, basedir, _ifname, ifstats, verbose)
  if(not ntop.exists(os_utils.fixPath(basedir.."/localstats/"))) then
    if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Creating localstats directory ", os_utils.fixPath(basedir.."/localstats"), '\n') end
    ntop.mkdir(os_utils.fixPath(basedir.."/localstats/"))
  end

  -- IN/OUT counters
  if(ifstats["localstats"]["bytes"]["local2remote"] > 0) then
    local name = os_utils.fixPath(basedir .. "/localstats/local2remote.rrd")
    createSingleRRDcounter(name, 300, verbose)
    ntop.rrd_update(name, nil, tolongint(ifstats["localstats"]["bytes"]["local2remote"]))
    if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
  end

  if(ifstats["localstats"]["bytes"]["remote2local"] > 0) then
    local name = os_utils.fixPath(basedir .. "/localstats/remote2local.rrd")
    createSingleRRDcounter(name, 300, verbose)
    ntop.rrd_update(name, nil, tolongint(ifstats["localstats"]["bytes"]["remote2local"]))
    if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
  end

  ntop.tsSet(when, ifstats.id, 300, "iface:localstats", "local2remote", "bytes",
    ifstats["localstats"]["bytes"]["local2remote"], ifstats["localstats"]["bytes"]["remote2local"])
end

-- ########################################################

function rrd_dump.host_update_stats_rrds(when, hostname, hostbase, host, ifstats, verbose)
  local name = os_utils.fixPath(hostbase.."/".."bytes.rrd")
  createRRDcounter(name, 300, verbose)
  ntop.rrd_update(name, nil, tolongint(host["bytes.sent"]), tolongint(host["bytes.rcvd"]))
  ntop.tsSet(when, ifstats.id, 300, 'ip', hostname, "bytes", tolongint(host["bytes.sent"]), tolongint(host["bytes.rcvd"]))

  if(verbose) then
    print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n')
  end

  -- Number of flows
  rrd_utils.makeRRD(hostbase, when, ifstats.id, "ip:"..hostname, "num_flows", 300, host["active_flows.as_client"] + host["active_flows.as_server"])

  -- L4 Protocols
  for id, _ in ipairs(l4_keys) do
    k = l4_keys[id][2]
    if((host[k..".bytes.sent"] ~= nil) and (host[k..".bytes.rcvd"] ~= nil)) then
      if(verbose) then print("["..__FILE__()..":"..__LINE__().."]\t"..k.."\n") end

      local name = os_utils.fixPath(hostbase .. "/".. k .. ".rrd")
      createRRDcounter(name, 300, verbose)
      -- io.write(name.."="..host[k..".bytes.sent"].."|".. host[k..".bytes.rcvd"] .. "\n")
      ntop.rrd_update(name, nil, tolongint(host[k..".bytes.sent"]), tolongint(host[k..".bytes.rcvd"]))
      ntop.tsSet(when, ifstats.id, 300, 'ip', hostname, tostring(k), tolongint(host[k..".bytes.sent"]), tolongint(host[k..".bytes.rcvd"]))

      if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
    else
      -- L2 host
      --io.write("Discarding "..k.."@"..hostname.."\n")
    end
  end
end

function rrd_dump.host_update_ndpi_rrds(when, hostname, hostbase, host, ifstats, verbose)
  -- nDPI Protocols
  for k in pairs(host["ndpi"] or {}) do
    local name = os_utils.fixPath(hostbase .. "/".. k .. ".rrd")
    createRRDcounter(name, 300, verbose)
    ntop.rrd_update(name, nil, tolongint(host["ndpi"][k]["bytes.sent"]), tolongint(host["ndpi"][k]["bytes.rcvd"]))
    ntop.tsSet(when, ifstats.id, 300, 'ip:ndpi', hostname, tostring(k),
    tolongint(host["ndpi"][k]["bytes.sent"]), tolongint(host["ndpi"][k]["bytes.rcvd"]))

    if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
  end
end

function rrd_dump.host_update_categories_rrds(when, hostname, hostbase, host, ifstats, verbose)
  -- nDPI Protocol CATEGORIES
  for k, cat in pairs(host["ndpi_categories"] or {}) do
    local name = os_utils.fixPath(hostbase .. "/".. k .. ".rrd")
    createSingleRRDcounter(name, 300, verbose)
    ntop.rrd_update(name, nil, tolongint(cat["bytes"]))
    ntop.tsSet(when, ifstats.id, 300, 'ip:ndpi_categories', hostname, tostring(k), tolongint(cat["bytes"]), 0)
    if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
  end
end

-- ########################################################

function rrd_dump.l2_device_update_categories_rrds(when, devicename, device, devicebase, ifstats, verbose)
  -- nDPI Protocol CATEGORIES
  for k, cat in pairs(device["ndpi_categories"] or {}) do
    local name = os_utils.fixPath(devicebase .. "/".. k .. ".rrd")
    createSingleRRDcounter(name, 300, verbose)
    ntop.rrd_update(name, nil, tolongint(cat["bytes"]))
    ntop.tsSet(when, ifstats.id, 300, 'mac:ndpi_categories', devicename, k, tolongint(cat["bytes"]), 0)

    if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
  end
end

function rrd_dump.l2_device_update_stats_rrds(when, devicename, device, devicebase, ifstats, verbose)
  local name = os_utils.fixPath(devicebase .. "/bytes.rrd")

  createRRDcounter(name, 300, verbose)
  ntop.rrd_update(name, nil, tolongint(device["bytes.sent"]), tolongint(device["bytes.rcvd"]))
  ntop.tsSet(when, ifstats.id, 300, 'mac', devicename, "bytes", tolongint(device["bytes.sent"]), tolongint(device["bytes.rcvd"]))
end

-- ########################################################

function rrd_dump.asn_update_rrds(when, ifstats, verbose)
  local basedir = os_utils.fixPath(dirs.workingdir .. "/" .. ifstats.id..'/asnstats')
  local asn_info = interface.getASesInfo({detailsLevel = "higher"})

  for _, asn_stats in ipairs(asn_info["ASes"]) do
    local asn = asn_stats["asn"]
    local asnpath = os_utils.fixPath(basedir.. "/" .. asn)

    if not ntop.exists(asnpath) then
      ntop.mkdir(asnpath)
    end

    -- Save ASN bytes
    local asn_bytes_rrd = os_utils.fixPath(asnpath .. "/bytes.rrd")
    createRRDcounter(asn_bytes_rrd, 300, false)
    if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..asn_bytes_rrd..'\n') end
    ntop.rrd_update(asn_bytes_rrd, nil, tolongint(asn_stats["bytes.sent"]), tolongint(asn_stats["bytes.rcvd"]))
    ntop.tsSet(when, ifstats.id, 300, 'asn', tostring(asn), "bytes",
    tolongint(asn_stats["bytes.sent"]), tolongint(asn_stats["bytes.rcvd"]))

    -- Save ASN ndpi stats
    if asn_stats["ndpi"] ~= nil then
      for proto_name, proto_stats in pairs(asn_stats["ndpi"]) do
        local asn_ndpi_rrd = os_utils.fixPath(asnpath.."/"..proto_name..".rrd")
        createRRDcounter(asn_ndpi_rrd, 300, verbose)
        ntop.rrd_update(asn_ndpi_rrd, nil, tolongint(proto_stats["bytes.sent"]), tolongint(proto_stats["bytes.rcvd"]))
        ntop.tsSet(when, ifstats.id, 300, 'asn:ndpi', tostring(asn), proto_name,
          tolongint(proto_stats["bytes.sent"]), tolongint(proto_stats["bytes.rcvd"]))
      end
    end
  end
end

-- ########################################################

function rrd_dump.vlan_update_rrds(when, ifstats, verbose)
  local basedir = os_utils.fixPath(dirs.workingdir .. "/" .. ifstats.id..'/vlanstats')
  local vlan_info = interface.getVLANsInfo()

  if(vlan_info ~= nil) and (vlan_info["VLANs"] ~= nil) then
    for _, vlan_stats in pairs(vlan_info["VLANs"]) do
      local vlan_id = vlan_stats["vlan_id"]

      local vlanpath = getPathFromKey(vlan_id)
      vlanpath = os_utils.fixPath(basedir.. "/" .. vlanpath)
      if not ntop.exists(vlanpath) then
        ntop.mkdir(vlanpath)
      end

      local vlanbytes = os_utils.fixPath(vlanpath .. "/bytes.rrd")
      createRRDcounter(vlanbytes, 300, false)
      if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..vlanbytes..'\n') end
      ntop.rrd_update(vlanbytes, nil, tolongint(vlan_stats["bytes.sent"]), tolongint(vlan_stats["bytes.rcvd"]))
      ntop.tsSet(when, ifstats.id, 300, 'vlan', tostring(vlan_id), "bytes",
        tolongint(vlan_stats["bytes.sent"]), tolongint(vlan_stats["bytes.rcvd"]))

      -- Save VLAN ndpi stats
      if vlan_stats["ndpi"] ~= nil then
        for proto_name, proto_stats in pairs(vlan_stats["ndpi"]) do
          local vlan_ndpi_rrd = os_utils.fixPath(vlanpath.."/"..proto_name..".rrd")
          createRRDcounter(vlan_ndpi_rrd, 300, verbose)
          ntop.rrd_update(vlan_ndpi_rrd, nil, tolongint(proto_stats["bytes.sent"]), tolongint(proto_stats["bytes.rcvd"]))
          ntop.tsSet(when, ifstats.id, 300, 'vlan:ndpi', tostring(vlan_id), proto_name,
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
      local base = getRRDName(ifstats.id, "sflow:"..flow_device_ip, port_idx)
      if(not(ntop.exists(base))) then ntop.mkdir(base) end

      local name = getRRDName(ifstats.id, "sflow:"..flow_device_ip, port_idx.."/bytes.rrd")
      createRRDcounter(name, 300, verbose)
      ntop.rrd_update(name, nil, tolongint(port_value.ifOutOctets), tolongint(port_value.ifInOctets))
      ntop.tsSet(when, ifstats.id, 300, "sflow", flow_device_ip, "bytes",
        tolongint(port_value.ifOutOctets), tolongint(port_value.ifInOctets))

      if(verbose) then
        print ("["..__FILE__()..":"..__LINE__().."]  Processing sFlow device "..flow_device_ip.." / port "..port_idx.." ["..name.."]\n")
      end
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
      local base = getRRDName(ifstats.id, "flow_device:"..flow_device_ip, port_idx)
      if(not(ntop.exists(base))) then ntop.mkdir(base) end

      local name = getRRDName(ifstats.id, "flow_device:"..flow_device_ip, port_idx.."/bytes.rrd")
      createRRDcounter(name, 300, verbose)
      ntop.rrd_update(name, nil, tolongint(port_value["bytes.out_bytes"]), tolongint(port_value["bytes.in_bytes"]))
      ntop.tsSet(when, ifstats.id, 300, "flow_device", flow_device_ip, "bytes",
          tolongint(port_value["bytes.out_bytes"]), tolongint(port_value["bytes.in_bytes"]))

      if(verbose) then
        print ("["..__FILE__()..":"..__LINE__().."]  Processing flow device "..flow_device_ip.." / port "..port_idx.." ["..name.."]\n")
      end
    end
  end
end

-- ########################################################

function rrd_dump.getConfig()
  local config = {}
  config.interface_rrd_creation = ntop.getPref("ntopng.prefs.interface_rrd_creation")
  config.interface_ndpi_timeseries_creation = ntop.getPref("ntopng.prefs.interface_ndpi_timeseries_creation")
  config.host_rrd_creation = ntop.getPref("ntopng.prefs.host_rrd_creation")
  config.host_ndpi_timeseries_creation = ntop.getPref("ntopng.prefs.host_ndpi_timeseries_creation")
  config.l2_device_rrd_creation = ntop.getPref("ntopng.prefs.l2_device_rrd_creation")
  config.l2_device_ndpi_timeseries_creation = ntop.getPref("ntopng.prefs.l2_device_ndpi_timeseries_creation")
  config.flow_devices_rrd_creation = ntop.getPref("ntopng.prefs.flow_device_port_rrd_creation")
  config.host_pools_rrd_creation = ntop.getPref("ntopng.prefs.host_pools_rrd_creation")
  config.snmp_devices_rrd_creation = ntop.getPref("ntopng.prefs.snmp_devices_rrd_creation")
  config.asn_rrd_creation = ntop.getPref("ntopng.prefs.asn_rrd_creation")
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

  -- Interface RRD creation is on, with per-protocol nDPI
  if isEmptyString(config.interface_rrd_creation) then config.interface_rrd_creation = "1" end
  if isEmptyString(config.interface_ndpi_timeseries_creation) then config.interface_ndpi_timeseries_creation = "per_protocol" end

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

  if is_rrd_creation_enabled then
    if config.interface_rrd_creation == "1" then
      local basedir = os_utils.fixPath(dirs.workingdir .. "/" .. ifstats.id .. "/rrd")

      if config.interface_ndpi_timeseries_creation == "per_protocol" or config.interface_ndpi_timeseries_creation == "both" then
        rrd_dump.iface_update_ndpi_rrds(when, basedir, _ifname, ifstats, verbose)
      end

      if config.interface_ndpi_timeseries_creation == "per_category" or config.interface_ndpi_timeseries_creation == "both" then
        rrd_dump.iface_update_categories_rrds(when, basedir, _ifname, ifstats, verbose)
      end

      rrd_dump.iface_update_stats_rrds(when, basedir, _ifname, ifstats, verbose)
    end
  end

  -- Save hosts stats (if enabled from the preferences)
  if is_rrd_creation_enabled or are_alerts_enabled then
    local in_time = callback_utils.foreachLocalHost(_ifname, time_threshold, function (hostname, host, hostbase)
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
