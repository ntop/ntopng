--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if (ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/callbacks/interface/?.lua;" .. package.path
   pcall(require, 'minute')
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
end

require "lua_utils"

local rrd_dump = require "rrd_min_dump_utils"

-- ########################################################

local verbose = ntop.verboseTrace()
local when = os.time()
local config = rrd_dump.getConfig()

local ifstats = interface.getStats()
local _ifname = ifstats.name

-- ########################################################

rrd_dump.run_min_dump(_ifname, ifstats, config, when, verbose)

local prefs = ntop.getPrefs()

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
      -- tprint("dumping ifname: "..ifname)

      -- to protect from failures (e.g., power losses) it is possible to save
      -- local hosts counters to redis once per hour
      interface.dumpLocalHosts2redis()
   end
end


