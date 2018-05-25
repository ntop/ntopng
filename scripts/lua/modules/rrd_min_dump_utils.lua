-- ########################################################

require "lua_utils"
require "alert_utils"
require "graph_utils"
require "rrd_utils"

local os_utils = require "os_utils"
local top_talkers_utils = require "top_talkers_utils"
local ts_utils = require("ts_utils")
local ts_schemas = require("ts_schemas")

local rrd_dump = {}

-- ########################################################

function rrd_dump.iface_update_ndpi_rrds(when, basedir, _ifname, ifstats, verbose)
  for k in pairs(ifstats["ndpi"]) do
    local v = ifstats["ndpi"][k]["bytes.sent"]+ifstats["ndpi"][k]["bytes.rcvd"]
    if(verbose) then print("["..__FILE__()..":"..__LINE__().."] ".._ifname..": "..k.."="..v.."\n") end

    ts_utils.append(ts_schemas.iface_ndpi(), {ifid=ifstats.id, protocol=k, bytes=v}, when, verbose)
    end
end

-- ########################################################

function rrd_dump.iface_update_categories_rrds(when, basedir, _ifname, ifstats, verbose)
  for k, v in pairs(ifstats["ndpi_categories"]) do
    v = v["bytes"]
    if(verbose) then print("["..__FILE__()..":"..__LINE__().."] ".._ifname..": "..k.."="..v.."\n") end

    ts_utils.append(ts_schemas.iface_ndpi_categories(), {ifid=ifstats.id, category=k, bytes=v}, when, verbose)
  end
end

-- ########################################################

function rrd_dump.iface_update_stats_rrds(when, basedir, _ifname, ifstats, verbose)
  -- IN/OUT counters
  if(ifstats["localstats"]["bytes"]["local2remote"] > 0) then
    ts_utils.append(ts_schemas.iface_local2remote(), {ifid=ifstats.id, bytes=ifstats["localstats"]["bytes"]["local2remote"]}, when, verbose)
  end

  if(ifstats["localstats"]["bytes"]["remote2local"] > 0) then
    ts_utils.append(ts_schemas.iface_remote2local(), {ifid=ifstats.id, bytes=ifstats["localstats"]["bytes"]["remote2local"]}, when, verbose)
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

    ts_utils.append(ts_schemas.subnet_traffic(), {ifid=ifstats.id, subnet=subnet,
              bytes_ingress=sstats["ingress"], bytes_egress=sstats["egress"],
              bytes_inner=sstats["inner"]}, when)

    ts_utils.append(ts_schemas.subnet_broadcast_traffic(), {ifid=ifstats.id, subnet=subnet,
              bytes_ingress=sstats["broadcast"]["ingress"], bytes_egress=sstats["broadcast"]["egress"],
              bytes_inner=sstats["broadcast"]["inner"]}, when, verbose)
  end
end

-- ########################################################

function rrd_dump.iface_update_general_stats(when, ifstats, basedir, verbose)
  -- General stats
  ts_utils.append(ts_schemas.iface_hosts(), {ifid=ifstats.id, num_hosts=ifstats.stats.hosts}, when, verbose)
  ts_utils.append(ts_schemas.iface_devices(), {ifid=ifstats.id, num_devices=ifstats.stats.devices}, when, verbose)
  ts_utils.append(ts_schemas.iface_flows(), {ifid=ifstats.id, num_flows=ifstats.stats.flows}, when, verbose)
  ts_utils.append(ts_schemas.iface_http_hosts(), {ifid=ifstats.id, num_hosts=ifstats.stats.http_hosts}, when, verbose)
end

function rrd_dump.iface_update_tcp_stats(when, ifstats, basedir, verbose)
  ts_utils.append(ts_schemas.iface_tcp_retransmissions(), {ifid=ifstats.id, packets=ifstats.tcpPacketStats.retransmissions}, when, verbose)
  ts_utils.append(ts_schemas.iface_tcp_out_of_order(), {ifid=ifstats.id, packets=ifstats.tcpPacketStats.out_of_order}, when, verbose)
  ts_utils.append(ts_schemas.iface_tcp_lost(), {ifid=ifstats.id, packets=ifstats.tcpPacketStats.lost}, when, verbose)
end

function rrd_dump.iface_update_tcp_flags(when, ifstats, basedir, verbose)
  ts_utils.append(ts_schemas.iface_tcp_syn(), {ifid=ifstats.id, packets=ifstats.pktSizeDistribution.syn}, when, verbose)
  ts_utils.append(ts_schemas.iface_tcp_synack(), {ifid=ifstats.id, packets=ifstats.pktSizeDistribution.synack}, when, verbose)
  ts_utils.append(ts_schemas.iface_tcp_finack(), {ifid=ifstats.id, packets=ifstats.pktSizeDistribution.finack}, when, verbose)
  ts_utils.append(ts_schemas.iface_tcp_rst(), {ifid=ifstats.id, packets=ifstats.pktSizeDistribution.rst}, when, verbose)
end

-- ########################################################

function rrd_dump.profiles_update_stats(when, ifstats, basedir, verbose)
  local basedir = os_utils.fixPath(dirs.workingdir .. "/" .. ifstats.id..'/profilestats')

  for pname, ptraffic in pairs(ifstats.profiles) do
    ts_utils.append(ts_schemas.profile_traffic(), {ifid=ifstats.id, profile=pname, bytes=ptraffic}, when, verbose)
  end
end

-- ########################################################

local function dumpTopTalkers(_ifname, ifstats, verbose)
  -- Dump topTalkers every minute
  local talkers = top_talkers_utils.makeTopJson(_ifname)

  if(verbose) then
    print("Computed talkers for interfaceId "..ifstats.id.."/"..ifstats.name.."\n")
    print(talkers)
  end

  ntop.insertMinuteSampling(ifstats.id, talkers)
end

function rrd_dump.run_min_dump(_ifname, ifstats, config, when, verbose)
  dumpTopTalkers(_ifname, ifstats, verbose)
  scanAlerts("min", ifstats)

  -- not even needed to check this as the function should only be called
  -- on interfaces that have rrd generation enabled
  if not interface_rrd_creation_enabled(ifstats.id) then
    return
  end

  local basedir = os_utils.fixPath(dirs.workingdir .. "/" .. ifstats.id .. "/rrd")
  if not ntop.exists(basedir) then ntop.mkdir(basedir) end

  rrd_dump.iface_update_stats_rrds(when, basedir, _ifname, ifstats, verbose)
  rrd_dump.iface_update_general_stats(when, ifstats, basedir, verbose)

  if config.interface_ndpi_timeseries_creation == "per_protocol" or config.interface_ndpi_timeseries_creation == "both" then
     rrd_dump.iface_update_ndpi_rrds(when, basedir, _ifname, ifstats, verbose)
  end

  if config.interface_ndpi_timeseries_creation == "per_category" or config.interface_ndpi_timeseries_creation == "both" then
     rrd_dump.iface_update_categories_rrds(when, basedir, _ifname, ifstats, verbose)
  end

  rrd_dump.subnet_update_rrds(when, ifstats, basedir, verbose)

  -- TCP stats
  if config.tcp_retr_ooo_lost_rrd_creation == "1" then
    rrd_dump.iface_update_tcp_stats(when, ifstats, basedir, verbose)
  end

  -- TCP Flags
  if config.tcp_flags_rrd_creation == "1" then
    rrd_dump.iface_update_tcp_flags(when, ifstats, basedir, verbose)
  end

  -- Save Profile stats every minute
  if ntop.isPro() and ifstats.profiles then  -- profiles are only available in the Pro version
    rrd_dump.profiles_update_stats(when, ifstats, basedir, verbose)
  end

  ts_utils.flush()
end

-- ########################################################

function rrd_dump.getConfig()
  local config = {}

  config.interface_ndpi_timeseries_creation = ntop.getPref("ntopng.prefs.interface_ndpi_timeseries_creation")
  config.tcp_flags_rrd_creation = ntop.getPref("ntopng.prefs.tcp_flags_rrd_creation")
  config.tcp_retr_ooo_lost_rrd_creation = ntop.getPref("ntopng.prefs.tcp_retr_ooo_lost_rrd_creation")

  -- Interface RRD creation is on, with per-protocol nDPI
  if isEmptyString(config.interface_ndpi_timeseries_creation) then config.interface_ndpi_timeseries_creation = "per_protocol" end

  return config
end

-- ########################################################

return rrd_dump
