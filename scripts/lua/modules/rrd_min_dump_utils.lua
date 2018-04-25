-- ########################################################

require "lua_utils"
require "alert_utils"
require "graph_utils"
local rrd_utils = require "rrd_utils"
local os_utils = require "os_utils"
local top_talkers_utils = require "top_talkers_utils"

local rrd_dump = {}

-- ########################################################

function rrd_dump.iface_update_ndpi_rrds(when, basedir, _ifname, ifstats, verbose)
  for k in pairs(ifstats["ndpi"]) do
    local v = ifstats["ndpi"][k]["bytes.sent"]+ifstats["ndpi"][k]["bytes.rcvd"]
    if(verbose) then print("["..__FILE__()..":"..__LINE__().."] ".._ifname..": "..k.."="..v.."\n") end

    local name = os_utils.fixPath(basedir .. "/"..k..".rrd")
    createSingleRRDcounter(name, 60, verbose)
    ntop.rrd_update(name, nil, tolongint(v))
    ntop.tsSet(when, 'iface:ndpi', tostring(k), "bytes", ifstats["ndpi"][k]["bytes.sent"], ifstats["ndpi"][k]["bytes.rcvd"])
    end
end

-- ########################################################

function rrd_dump.iface_update_categories_rrds(when, basedir, _ifname, ifstats, verbose)
  for k, v in pairs(ifstats["ndpi_categories"]) do
    v = v["bytes"]
    if(verbose) then print("["..__FILE__()..":"..__LINE__().."] ".._ifname..": "..k.."="..v.."\n") end

    local name = os_utils.fixPath(basedir .. "/"..k..".rrd")
    createSingleRRDcounter(name, 60, verbose)
    ntop.rrd_update(name, nil, tolongint(v))
    ntop.tsSet(when, 'iface:ndpi_categories', tostring(k), "bytes", v, 0)
  end
end

-- ########################################################

function rrd_dump.iface_update_stats_rrds(when, basedir, _ifname, ifstats, verbose)
  if(not ntop.exists(os_utils.fixPath(basedir.."/localstats/"))) then
    if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Creating localstats directory ", os_utils.fixPath(basedir.."/localstats"), '\n') end
    ntop.mkdir(os_utils.fixPath(basedir.."/localstats/"))
  end

  -- IN/OUT counters
  if(ifstats["localstats"]["bytes"]["local2remote"] > 0) then
    local name = os_utils.fixPath(basedir .. "/localstats/local2remote.rrd")
    createSingleRRDcounter(name, 60, verbose)
    ntop.rrd_update(name, nil, tolongint(ifstats["localstats"]["bytes"]["local2remote"]))
    if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
  end

  if(ifstats["localstats"]["bytes"]["remote2local"] > 0) then
    local name = os_utils.fixPath(basedir .. "/localstats/remote2local.rrd")
    createSingleRRDcounter(name, 60, verbose)
    ntop.rrd_update(name, nil, tolongint(ifstats["localstats"]["bytes"]["remote2local"]))
    if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
  end

  ntop.tsSet(when, "iface:localstats", "local2remote", "bytes",
    ifstats["localstats"]["bytes"]["local2remote"], ifstats["localstats"]["bytes"]["remote2local"])
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
    ntop.tsSet(when, "iface:subnetstats", subnet, "bytes", tolongint(sstats["egress"]), tolongint(sstats["inner"]))

    local bytes_bcast_rrd = os_utils.fixPath(rrdpath .. "/broadcast_bytes.rrd")
    createTripleRRDcounter(bytes_bcast_rrd, 60, false)  -- 60(s) == 1 minute step
    ntop.rrd_update(bytes_bcast_rrd, nil, tolongint(sstats["broadcast"]["ingress"]), tolongint(sstats["broadcast"]["egress"]), tolongint(sstats["broadcast"]["inner"]))
    ntop.tsSet(when, "iface:subnetstats", subnet, "broadcast_bytes", tolongint(sstats["broadcast"]["ingress"]), tolongint(sstats["broadcast"]["egress"]))
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
    ntop.tsSet(when, 'profilestats', pname, "bytes", tolongint(ptraffic), 0)
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
