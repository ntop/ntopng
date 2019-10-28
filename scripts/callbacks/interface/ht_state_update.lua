--
-- (C) 2019 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local ts_utils = require "ts_utils_core"
require "ts_5sec"
local ts_dump = require "ts_5sec_dump_utils"

-- Keep it in sync with HT_STATE_UPDATE_SCRIPT_PATH periodicity in PeriodicActivities.cpp
-- that is, with the frequency of execution of this script.
local HT_STATE_UPDATE_FREQ = 5 

-- ########################################################

local deadline = os.time() + HT_STATE_UPDATE_FREQ
local periodic_ht_state_update_stats = interface.periodicHTStateUpdate(deadline)
ts_dump.run_5sec_dump(interface.getId(), periodic_ht_state_update_stats)

-- ########################################################

