--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
local ts_dump = require "ts_min_dump_utils"

-- ########################################################

local verbose = ntop.verboseTrace()
local when = os.time()
local ifstats = interface.getStats()
local _ifname = ifstats.name

-- ########################################################

-- Dumping timeseries stats
ts_dump.run_min_dump(_ifname, ifstats, when, verbose)

-- High resolution requested, dump 5 minutes timeseries each minute
if hasHighResolutionTs() then
   local ts_5min_dump = require "ts_5min_dump_utils"

   ts_5min_dump.run_5min_dump(_ifname, ifstats, when, verbose)
end


