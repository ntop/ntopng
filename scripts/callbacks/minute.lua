--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if (ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
   require("minute")

   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
end

require "lua_utils"
require "graph_utils"
require "rrd_utils"

local rrd_dump = require "rrd_min_dump_utils"
local callback_utils = require "callback_utils"

-- ########################################################

local config = rrd_dump.getConfig()
local when = os.time()
local verbose = ntop.verboseTrace()
local ifnames = interface.getIfNames()

if((_GET ~= nil) and (_GET["verbose"] ~= nil)) then
   verbose = true
end

if(verbose) then
   sendHTTPHeader('text/plain')
end

callback_utils.foreachInterface(ifnames, nil, function(_ifname, ifstats)
   rrd_dump.run_min_dump(_ifname, ifstats, config, when, verbose)
end) -- foreachInterface

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
