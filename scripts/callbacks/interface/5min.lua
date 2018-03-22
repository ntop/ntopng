--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/interface/?.lua;" .. package.path
  pcall(require, '5min')
end

require "lua_utils"
local rrd_dump = require "rrd_5min_dump_utils"

-- ########################################################

local verbose = ntop.verboseTrace()
local when = os.time()
local config = rrd_dump.getConfig()
local time_threshold = when - (when % 300) --[[ align ]] + (5 * 300) --[[ RRD heartbeat ]] - 10 --[[ safe margin ]]

local ifstats = interface.getStats()
local _ifname = ifstats.name

-- ########################################################

rrd_dump.run_5min_dump(_ifname, ifstats, config, when, time_threshold, verbose)
