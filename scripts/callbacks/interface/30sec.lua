--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rrd_dump = require "rrd_30sec_dump_utils"

-- ########################################################

local verbose = ntop.verboseTrace()
local when = os.time()
local config = rrd_dump.getConfig()
local time_threshold = when - (when % 30) --[[ align ]] + (5 * 30) --[[ RRD heartbeat ]] - 10 --[[ safe margin ]]

local ifstats = interface.getStats()
local _ifname = ifstats.name

-- ########################################################

rrd_dump.run_30sec_dump(_ifname, ifstats, config, when, time_threshold, verbose)
