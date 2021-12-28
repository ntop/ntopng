--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local db_utils = require "db_utils"
local data_retention_utils = require "data_retention_utils"

-- ########################################################

if ntop.isClickHouseEnabled() then
   local data_retention = data_retention_utils.getDataRetentionDays()
   local mysql_retention = os.time() - 86400 * data_retention

   db_utils.clickhouseDeleteOldPartitions(mysql_retention)
end
