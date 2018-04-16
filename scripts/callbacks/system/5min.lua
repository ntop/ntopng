--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/system/?.lua;" .. package.path
  pcall(require, '5min')

  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
  require "snmp_utils"
end

require "lua_utils"
local rrd_dump = require "rrd_5min_dump_utils"

-- ########################################################

local verbose = ntop.verboseTrace()
local when = os.time()
local config = rrd_dump.getConfig()
local time_threshold = when - (when % 300) + 300 - 10 -- safe margin

-- ########################################################

-- This must be placed at the end of the script
if ntop.isPro() then
  snmp_update_rrds(config, time_threshold, verbose)
end
