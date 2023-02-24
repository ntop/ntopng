--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local scripts_triggers = require "scripts_triggers"

-- ########################################################

if(ntop.isClickHouseEnabled()) then
   local db_utils = require "db_utils"
   local data_retention_utils = require "data_retention_utils"
   local data_retention_days = data_retention_utils.getFlowsAndAlertsDataRetentionDays()
   local data_retention = os.time() - 86400 * data_retention_days
   
   db_utils.clickhouseDeleteOldPartitions(data_retention)

   -- print("Purging < "..data_retention_days.." days ClickHouse records\n")
end
