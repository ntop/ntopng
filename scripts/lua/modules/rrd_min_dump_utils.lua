-- ########################################################

require "lua_utils"
require "top_structure"
require "alert_utils"
require "graph_utils"
local rrd_utils = require "rrd_utils"
local os_utils = require "os_utils"

local rrd_dump = {}

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

local function dumpTopTalkers(_ifname, ifstats, verbose)
  -- Dump topTalkers every minute
  local talkers = makeTopJSON(ifstats.id, _ifname)

  if(verbose) then
    print("Computed talkers for interfaceId "..ifstats.id.."/"..ifstats.name.."\n")
    print(talkers)
  end

  ntop.insertMinuteSampling(ifstats.id, talkers)
end

function rrd_dump.run_min_dump(_ifname, ifstats, config, when, verbose)
  dumpTopTalkers(_ifname, ifstats, verbose)
  scanAlerts("min", ifstats)

  if not interface_rrd_creation_enabled(ifstats.id) then
    return
  end

  -- TODO secondStats = interface.getLastMinuteTrafficStats()
  -- TODO send secondStats to collector

  local basedir = os_utils.fixPath(dirs.workingdir .. "/" .. ifstats.id .. "/rrd")
  if not ntop.exists(basedir) then ntop.mkdir(basedir) end

  rrd_dump.subnet_update_rrds(when, ifstats, basedir, verbose)
  rrd_dump.iface_update_general_stats(when, ifstats, basedir, verbose)

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

  config.tcp_flags_rrd_creation = ntop.getPref("ntopng.prefs.tcp_flags_rrd_creation")
  config.tcp_retr_ooo_lost_rrd_creation = ntop.getPref("ntopng.prefs.tcp_retr_ooo_lost_rrd_creation")

  return config
end

-- ########################################################

return rrd_dump
