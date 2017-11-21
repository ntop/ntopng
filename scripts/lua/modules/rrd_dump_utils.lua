
require "graph_utils"
require "lua_utils"

local rrd_dump = {}

-- ########################################################

function rrd_dump.iface_update_ndpi_rrds(when, basedir, _ifname, ifstats, verbose)
  for k in pairs(ifstats["ndpi"]) do
    local v = ifstats["ndpi"][k]["bytes.sent"]+ifstats["ndpi"][k]["bytes.rcvd"]
    if(verbose) then print("["..__FILE__()..":"..__LINE__().."] ".._ifname..": "..k.."="..v.."\n") end

    local name = fixPath(basedir .. "/"..k..".rrd")
    createSingleRRDcounter(name, 300, verbose)
    ntop.rrd_update(name, nil, tolongint(v))
    ntop.tsSet(when, ifstats.id, 300, 'iface:ndpi', tostring(k), "bytes", ifstats["ndpi"][k]["bytes.sent"], ifstats["ndpi"][k]["bytes.rcvd"])
    end
end

function rrd_dump.iface_update_categories_rrds(when, basedir, _ifname, ifstats, verbose)
  for k, v in pairs(ifstats["ndpi_categories"]) do
    v = v["bytes"]
    if(verbose) then print("["..__FILE__()..":"..__LINE__().."] ".._ifname..": "..k.."="..v.."\n") end

    local name = fixPath(basedir .. "/"..k..".rrd")
    createSingleRRDcounter(name, 300, verbose)
    ntop.rrd_update(name, nil, tolongint(v))
    ntop.tsSet(when, ifstats.id, 300, 'iface:ndpi_categories', tostring(k), "bytes", v, 0)
  end
end

function rrd_dump.iface_update_stats_rrds(when, basedir, _ifname, ifstats, verbose)
  if(not ntop.exists(fixPath(basedir.."/localstats/"))) then
    if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Creating localstats directory ", fixPath(basedir.."/localstats"), '\n') end
    ntop.mkdir(fixPath(basedir.."/localstats/"))
  end

  -- IN/OUT counters
  if(ifstats["localstats"]["bytes"]["local2remote"] > 0) then
    local name = fixPath(basedir .. "/localstats/local2remote.rrd")
    createSingleRRDcounter(name, 300, verbose)
    ntop.rrd_update(name, nil, tolongint(ifstats["localstats"]["bytes"]["local2remote"]))
    if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
  end

  if(ifstats["localstats"]["bytes"]["remote2local"] > 0) then
    local name = fixPath(basedir .. "/localstats/remote2local.rrd")
    createSingleRRDcounter(name, 300, verbose)
    ntop.rrd_update(name, nil, tolongint(ifstats["localstats"]["bytes"]["remote2local"]))
    if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
  end

  ntop.tsSet(when, ifstats.id, 300, "iface:localstats", "local2remote", "bytes",
    ifstats["localstats"]["bytes"]["local2remote"], ifstats["localstats"]["bytes"]["remote2local"])
end

-- ########################################################

function rrd_dump.host_update_stats_rrds(when, hostname, hostbase, host, ifstats, verbose)
  local name = fixPath(hostbase.."/".."bytes.rrd")
  createRRDcounter(name, 300, verbose)
  ntop.rrd_update(name, nil, tolongint(host["bytes.sent"]), tolongint(host["bytes.rcvd"]))
  ntop.tsSet(when, ifstats.id, 300, 'ip', hostname, "bytes", tolongint(host["bytes.sent"]), tolongint(host["bytes.rcvd"]))

  if(verbose) then
    print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n')
  end

  -- Number of flows
  makeRRD(hostbase, when, ifstats.id, "ip:"..hostname, "num_flows", 300, host["active_flows.as_client"] + host["active_flows.as_server"])

  -- L4 Protocols
  for id, _ in ipairs(l4_keys) do
    k = l4_keys[id][2]
    if((host[k..".bytes.sent"] ~= nil) and (host[k..".bytes.rcvd"] ~= nil)) then
      if(verbose) then print("["..__FILE__()..":"..__LINE__().."]\t"..k.."\n") end

      local name = fixPath(hostbase .. "/".. k .. ".rrd")
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
    local name = fixPath(hostbase .. "/".. k .. ".rrd")
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
    local name = fixPath(hostbase .. "/".. k .. ".rrd")
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
    local name = fixPath(devicebase .. "/".. k .. ".rrd")
    createSingleRRDcounter(name, 300, verbose)
    ntop.rrd_update(name, nil, tolongint(cat["bytes"]))
    ntop.tsSet(when, ifstats.id, 300, 'mac:ndpi_categories', devicename, k, tolongint(cat["bytes"]), 0)

    if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
  end
end

function rrd_dump.l2_device_update_stats_rrds(when, devicename, device, devicebase, ifstats, verbose)
  local name = fixPath(devicebase .. "/bytes.rrd")

  createRRDcounter(name, 300, verbose)
  ntop.rrd_update(name, nil, tolongint(device["bytes.sent"]), tolongint(device["bytes.rcvd"]))
  ntop.tsSet(when, ifstats.id, 300, 'mac', devicename, "bytes", tolongint(device["bytes.sent"]), tolongint(device["bytes.rcvd"]))
end

-- ########################################################

function rrd_dump.asn_update_rrds(when, ifstats, verbose)
  local basedir = fixPath(dirs.workingdir .. "/" .. ifstats.id..'/asnstats')
  local asn_info = interface.getASesInfo({detailsLevel = "higher"})

  for _, asn_stats in ipairs(asn_info["ASes"]) do
    local asn = asn_stats["asn"]
    local asnpath = fixPath(basedir.. "/" .. asn)

    if not ntop.exists(asnpath) then
      ntop.mkdir(asnpath)
    end

    -- Save ASN bytes
    local asn_bytes_rrd = fixPath(asnpath .. "/bytes.rrd")
    createRRDcounter(asn_bytes_rrd, 300, false)
    if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..asn_bytes_rrd..'\n') end
    ntop.rrd_update(asn_bytes_rrd, nil, tolongint(asn_stats["bytes.sent"]), tolongint(asn_stats["bytes.rcvd"]))
    ntop.tsSet(when, ifstats.id, 300, 'asn', tostring(asn), "bytes",
    tolongint(asn_stats["bytes.sent"]), tolongint(asn_stats["bytes.rcvd"]))

    -- Save ASN ndpi stats
    if asn_stats["ndpi"] ~= nil then
      for proto_name, proto_stats in pairs(asn_stats["ndpi"]) do
        local asn_ndpi_rrd = fixPath(asnpath.."/"..proto_name..".rrd")
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
  local basedir = fixPath(dirs.workingdir .. "/" .. ifstats.id..'/vlanstats')
  local vlan_info = interface.getVLANsInfo()

  if(vlan_info ~= nil) and (vlan_info["VLANs"] ~= nil) then
    for _, vlan_stats in pairs(vlan_info["VLANs"]) do
      local vlan_id = vlan_stats["vlan_id"]

      local vlanpath = getPathFromKey(vlan_id)
      vlanpath = fixPath(basedir.. "/" .. vlanpath)
      if not ntop.exists(vlanpath) then
        ntop.mkdir(vlanpath)
      end

      local vlanbytes = fixPath(vlanpath .. "/bytes.rrd")
      createRRDcounter(vlanbytes, 300, false)
      if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..vlanbytes..'\n') end
      ntop.rrd_update(vlanbytes, nil, tolongint(vlan_stats["bytes.sent"]), tolongint(vlan_stats["bytes.rcvd"]))
      ntop.tsSet(when, ifstats.id, 300, 'vlan', tostring(vlan_id), "bytes",
        tolongint(vlan_stats["bytes.sent"]), tolongint(vlan_stats["bytes.rcvd"]))

      -- Save VLAN ndpi stats
      if vlan_stats["ndpi"] ~= nil then
        for proto_name, proto_stats in pairs(vlan_stats["ndpi"]) do
          local vlan_ndpi_rrd = fixPath(vlanpath.."/"..proto_name..".rrd")
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

return rrd_dump
