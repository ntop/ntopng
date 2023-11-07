--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path
require "lua_utils"
-- Toggle debug
local enable_second_debug = false
local when = os.time()

local ts_dump = require "ts_5min_dump_utils"
ts_dump.blacklist_update(when)
