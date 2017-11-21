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
require "rrd_utils"

local rrd_dump = require "rrd_dump_utils"
local tcp_flags_rrd_creation = ntop.getPref("ntopng.prefs.tcp_flags_rrd_creation")
local tcp_retr_ooo_lost_rrd_creation = ntop.getPref("ntopng.prefs.tcp_retr_ooo_lost_rrd_creation")
local callback_utils = require "callback_utils"

local prefs = ntop.getPrefs()

-- ########################################################

local when = os.time()

local verbose = ntop.verboseTrace()
local ifnames = interface.getIfNames()

if((_GET ~= nil) and (_GET["verbose"] ~= nil)) then
   verbose = true
end

if(verbose) then
   sendHTTPHeader('text/plain')
end

-- We must scan the alerts on all the interfaces, not only the ones with interface_rrd_creation_enabled
callback_utils.foreachInterface(ifnames, nil, function(_ifname, ifstats)
   scanAlerts("min", ifstats)
end)

callback_utils.foreachInterface(ifnames, interface_rrd_creation_enabled, function(_ifname, ifstats)
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

      local basedir = fixPath(dirs.workingdir .. "/" .. ifstats.id .. "/rrd")
      if not ntop.exists(basedir) then ntop.mkdir(basedir) end

      rrd_dump.subnet_update_rrds(when, ifstats, basedir, verbose)
      rrd_dump.iface_update_general_stats(when, ifstats, basedir)

      -- TCP stats
      if tcp_retr_ooo_lost_rrd_creation == "1" then
         rrd_dump.iface_update_tcp_stats(when, ifstats, basedir)
      end

      -- TCP Flags
      if tcp_flags_rrd_creation == "1" then
         rrd_dump.iface_update_tcp_flags(when, ifstats, basedir)
      end

      -- Save Profile stats every minute
      if ntop.isPro() and ifstats.profiles then  -- profiles are only available in the Pro version
        rrd_dump.profiles_update_stats(when, ifstats, basedir)
      end
end) -- foreachInterface

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

ntop.tsFlush(tonumber(60))
