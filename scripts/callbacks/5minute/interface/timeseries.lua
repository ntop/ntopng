--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local ts_dump = require "ts_5min_dump_utils"

-- ########################################################

-- @brief Execute the timeseries dump for 5 min stats
--        if no high resolution Timeseries is requested
--        otherwise run this dump into the minute dump 

if not hasHighResolutionTs() then
  local config = ts_dump.getConfig()
  local when = os.time()
  local ifstats = interface.getStats()
  local _ifname = ifstats.name
  local verbose = ntop.verboseTrace()

  ts_dump.run_5min_dump(_ifname, ifstats, config, when, verbose)
end
