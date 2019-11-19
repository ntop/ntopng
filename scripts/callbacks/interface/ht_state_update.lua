--
-- (C) 2019 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local ts_utils = require "ts_utils_core"
require "ts_5sec"
local ts_dump = require "ts_5sec_dump_utils"
local when = os.time()

-- ########################################################

-- deadline is expected to be set as global variable from the C which invokes this script
local periodic_ht_state_update_stats = interface.periodicHTStateUpdate(deadline)
ts_dump.run_5sec_dump(interface.getId(), when, periodic_ht_state_update_stats)

-- ########################################################

