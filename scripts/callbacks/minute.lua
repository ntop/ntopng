--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "alert_utils"
if (ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
   require("minute")

   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
end

require "lua_utils"
require "graph_utils"
require "top_structure"
local tcp_flags_rrd_creation = ntop.getPref("ntopng.prefs.tcp_flags_rrd_creation")
local tcp_retr_ooo_lost_rrd_creation = ntop.getPref("ntopng.prefs.tcp_retr_ooo_lost_rrd_creation")
local callback_utils = require "callback_utils"

local prefs = ntop.getPrefs()

-- ########################################################

local when = os.time()

local verbose = ntop.verboseTrace()
local ifnames = interface.getIfNames()

-- Scan "minute" alerts
callback_utils.foreachInterface(ifnames, verbose, function(ifname, ifstats)
   scanAlerts("min", ifname)
end)

if((_GET ~= nil) and (_GET["verbose"] ~= nil)) then
   verbose = true
end

if(verbose) then
   sendHTTPHeader('text/plain')
end

callback_utils.foreachInterface(ifnames, verbose, function(_ifname, ifstats)
      -- NOTE: this limits talkers lifetime to reduce memory footprint later on this script
      do
        -- Dump topTalkers every minute
        local talkers = makeTopJSON(ifstats.id, _ifname)
        if(verbose) then
          print("Computed talkers for interfaceId "..ifstats.id.."/"..ifstats.name.."\n")
          print(talkers)
        end
        ntop.insertMinuteSampling(ifstats.id, talkers)
      end

      -- TODO secondStats = interface.getLastMinuteTrafficStats()
      -- TODO send secondStats to collector

      -- Save local subnets stats every minute
      basedir = fixPath(dirs.workingdir .. "/" .. ifstats.id..'/subnetstats')
      local subnet_stats = interface.getNetworksStats()
      for subnet,sstats in pairs(subnet_stats) do
	 local rrdpath = getPathFromKey(subnet)
	 rrdpath = fixPath(basedir.. "/" .. rrdpath)
	 if(not(ntop.exists(rrdpath))) then
	    ntop.mkdir(rrdpath)
	 end

	 local bytes_rrd = fixPath(rrdpath .. "/bytes.rrd")
	 createTripleRRDcounter(bytes_rrd, 60, false)  -- 60(s) == 1 minute step
	 ntop.rrd_update(bytes_rrd, "N:"..tolongint(sstats["ingress"]) .. ":" .. tolongint(sstats["egress"]) .. ":" .. tolongint(sstats["inner"]))

	 local bytes_bcast_rrd = fixPath(rrdpath .. "/broadcast_bytes.rrd")
	 tprint(subnet)
	 tprint(sstats["broadcast"])
	 createTripleRRDcounter(bytes_bcast_rrd, 60, false)  -- 60(s) == 1 minute step
	 ntop.rrd_update(bytes_bcast_rrd, "N:"..tolongint(sstats["broadcast"]["ingress"]) .. ":" .. tolongint(sstats["broadcast"]["egress"]) .. ":" .. tolongint(sstats["broadcast"]["inner"]))
      end

      basedir = fixPath(dirs.workingdir .. "/" .. ifstats.id .. "/rrd")
      if not ntop.exists(basedir) then ntop.mkdir(basedir) end

      -- General stats
      makeRRD(basedir, _ifname, "num_hosts", 60, ifstats.stats.hosts)
      makeRRD(basedir, _ifname, "num_devices", 60, ifstats.stats.devices)
      makeRRD(basedir, _ifname, "num_flows", 60, ifstats.stats.flows)
      makeRRD(basedir, _ifname, "num_http_hosts", 60, ifstats.stats.http_hosts)

      -- TCP stats
      if tcp_retr_ooo_lost_rrd_creation == "1" then
	 makeRRD(basedir, _ifname, "tcp_retransmissions", 60, ifstats.tcpPacketStats.retransmissions)
	 makeRRD(basedir, _ifname, "tcp_ooo", 60, ifstats.tcpPacketStats.out_of_order)
	 makeRRD(basedir, _ifname, "tcp_lost", 60, ifstats.tcpPacketStats.lost)
      end

      -- TCP Flags
      if tcp_flags_rrd_creation == "1" then
         makeRRD(basedir, _ifname, "tcp_syn", 60, ifstats.pktSizeDistribution.syn)
         makeRRD(basedir, _ifname, "tcp_synack", 60, ifstats.pktSizeDistribution.synack)
         makeRRD(basedir, _ifname, "tcp_finack", 60, ifstats.pktSizeDistribution.finack)
         makeRRD(basedir, _ifname, "tcp_rst", 60, ifstats.pktSizeDistribution.rst)
     end

      -- Save Profile stats every minute
      if ntop.isPro() and ifstats.profiles then  -- profiles are only available in the Pro version
	 basedir = fixPath(dirs.workingdir .. "/" .. ifstats.id..'/profilestats')
	 for pname, ptraffic in pairs(ifstats.profiles) do
	    local rrdpath = fixPath(basedir.. "/" .. getPathFromKey(trimSpace(pname)))
	    if(not(ntop.exists(rrdpath))) then
	       ntop.mkdir(rrdpath)
	    end
	    rrdpath = fixPath(rrdpath .. "/bytes.rrd")
	    createSingleRRDcounter(rrdpath, 60, false)  -- 60(s) == 1 minute step
	    ntop.rrd_update(rrdpath, "N:"..tolongint(ptraffic))
	 end
      end
end) -- foreachInterface

-- check MySQL open files status
-- NOTE: performed on startup.lua
-- checkOpenFiles()

-- when the active local hosts cache is enabled, ntopng periodically dumps active local hosts statistics to redis
-- in order to protect from failures (e.g., power losses)
if prefs.is_active_local_hosts_cache_enabled then
   local interval = prefs.active_local_hosts_cache_interval
   local diff = when % tonumber((interval or 3600 --[[ default 1 h --]]))

   --[[
   tprint("interval: "..tostring(interval))
   tprint("when: "..tostring(when))
   tprint("diff: "..tostring(diff))
   --]]

   if diff < 60 then
      for _, ifname in pairs(ifnames) do
	 -- tprint("dumping ifname: "..ifname)

	 -- to protect from failures (e.g., power losses) it is possible to save
	 -- local hosts counters to redis once per hour
	 interface.select(ifname)
	 interface.dumpLocalHosts2redis()
      end

   end
end
