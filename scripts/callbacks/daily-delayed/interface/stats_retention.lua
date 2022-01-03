--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local data_retention_utils = require "data_retention_utils"

-- ########################################################

local interface_id = interface.getId()

-- ########################################################

local data_retention = data_retention_utils.getDataRetentionDays()

-- ###########################################

ntop.deleteMinuteStatsOlderThan(interface_id, data_retention)

