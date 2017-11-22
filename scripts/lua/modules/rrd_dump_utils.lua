require "lua_utils"
local rrd_utils = require "rrd_utils"
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

function rrd_dump.subnet_update_rrds(when, ifstats, basedir, verbose)
  local basedir = os_utils.fixPath(dirs.workingdir .. "/" .. ifstats.id..'/subnetstats')
  local subnet_stats = interface.getNetworksStats()

  for subnet,sstats in pairs(subnet_stats) do
    local rrdpath = getPathFromKey(subnet)
    rrdpath = os_utils.fixPath(basedir.. "/" .. rrdpath)
    if(not(ntop.exists(rrdpath))) then
       ntop.mkdir(rrdpath)
    end

    local bytes_rrd = os_utils.fixPath(rrdpath .. "/bytes.rrd")
    createTripleRRDcounter(bytes_rrd, 60, false)  -- 60(s) == 1 minute step
    ntop.rrd_update(bytes_rrd, nil, tolongint(sstats["ingress"]), tolongint(sstats["egress"]), tolongint(sstats["inner"]))
    ntop.tsSet(when, ifstats.id, 60, "iface:subnetstats", subnet, "bytes", tolongint(sstats["egress"]), tolongint(sstats["inner"]))

    local bytes_bcast_rrd = os_utils.fixPath(rrdpath .. "/broadcast_bytes.rrd")
    createTripleRRDcounter(bytes_bcast_rrd, 60, false)  -- 60(s) == 1 minute step
    ntop.rrd_update(bytes_bcast_rrd, nil, tolongint(sstats["broadcast"]["ingress"]), tolongint(sstats["broadcast"]["egress"]), tolongint(sstats["broadcast"]["inner"]))
    ntop.tsSet(when, ifstats.id, 60, "iface:subnetstats", subnet, "broadcast_bytes", tolongint(sstats["broadcast"]["ingress"]), tolongint(sstats["broadcast"]["egress"]))
  end
end

-- ########################################################

function rrd_dump.iface_update_general_stats(when, ifstats, basedir, verbose)
  -- General stats
  rrd_utils.makeRRD(basedir, when, ifstats.id, "iface", "num_hosts", 60, ifstats.stats.hosts)
  rrd_utils.makeRRD(basedir, when, ifstats.id, "iface", "num_devices", 60, ifstats.stats.devices)
  rrd_utils.makeRRD(basedir, when, ifstats.id, "iface", "num_flows", 60, ifstats.stats.flows)
  rrd_utils.makeRRD(basedir, when, ifstats.id, "iface", "num_http_hosts", 60, ifstats.stats.http_hosts)
end

function rrd_dump.iface_update_tcp_stats(when, ifstats, basedir, verbose)
  rrd_utils.makeRRD(basedir, when, ifstats.id, "iface", "tcp_retransmissions", 60, ifstats.tcpPacketStats.retransmissions)
  rrd_utils.makeRRD(basedir, when, ifstats.id, "iface", "tcp_ooo", 60, ifstats.tcpPacketStats.out_of_order)
  rrd_utils.makeRRD(basedir, when, ifstats.id, "iface", "tcp_lost", 60, ifstats.tcpPacketStats.lost)
end

function rrd_dump.iface_update_tcp_flags(when, ifstats, basedir, verbose)
  rrd_utils.makeRRD(basedir, when, ifstats.id, "iface", "tcp_syn", 60, ifstats.pktSizeDistribution.syn)
  rrd_utils.makeRRD(basedir, when, ifstats.id, "iface", "tcp_synack", 60, ifstats.pktSizeDistribution.synack)
  rrd_utils.makeRRD(basedir, when, ifstats.id, "iface", "tcp_finack", 60, ifstats.pktSizeDistribution.finack)
  rrd_utils.makeRRD(basedir, when, ifstats.id, "iface", "tcp_rst", 60, ifstats.pktSizeDistribution.rst)
end

-- ########################################################

function rrd_dump.profiles_update_stats(when, ifstats, basedir, verbose)
  local basedir = os_utils.fixPath(dirs.workingdir .. "/" .. ifstats.id..'/profilestats')

  for pname, ptraffic in pairs(ifstats.profiles) do
    local rrdpath = os_utils.fixPath(basedir.. "/" .. getPathFromKey(trimSpace(pname)))
    if(not(ntop.exists(rrdpath))) then
      ntop.mkdir(rrdpath)
    end
    rrdpath = os_utils.fixPath(rrdpath .. "/bytes.rrd")
    createSingleRRDcounter(rrdpath, 60, false)  -- 60(s) == 1 minute step
    ntop.rrd_update(rrdpath, nil, tolongint(ptraffic))
    ntop.tsSet(when, ifstats.id, 60, 'profilestats', pname, "bytes", tolongint(ptraffic), 0)
  end
end

-- ########################################################

return rrd_dump
