--
-- (C) 2019-26 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/schemas/?.lua;" .. package.path

-- ########################################################

local ts_utils = require "ts_utils_core"
local ts_dump = require "ts_5sec_dump_utils"

-- ########################################################

require "ts_5sec"

ts_dump.update_rrd_queue_length(interface.getId(), when)
