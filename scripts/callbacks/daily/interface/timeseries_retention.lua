--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

-- ########################################################

local ts_utils = require "ts_utils"

-- ########################################################

local ifstats = interface.getStats()
local interface_id = ifstats.id

-- ########################################################

ts_utils.deleteOldData(interface_id)
