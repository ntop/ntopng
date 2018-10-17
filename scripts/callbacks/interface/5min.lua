--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/interface/?.lua;" .. package.path
  pcall(require, '5min')
end

-- keep calling this before including modules to avoid that the 
-- current interface is changed by (unexpected) interface.select() calls
local ifstats = interface.getStats()

require "lua_utils"
local ts_utils = require("ts_utils_core")
local rrd_dump = require "rrd_5min_dump_utils"

-- ########################################################

local verbose = ntop.verboseTrace()
local when = os.time()
local config = rrd_dump.getConfig()
local time_threshold = when - (when % 300) --[[ align ]] + (5 * 300) --[[ RRD heartbeat ]] - 10 --[[ safe margin ]]

local _ifname = ifstats.name

-- ########################################################

local skip_ts = ts_utils.hasHighResolutionTs()
rrd_dump.run_5min_dump(_ifname, ifstats, config, when, time_threshold, skip_ts, false --[[skip alerts]], verbose)
