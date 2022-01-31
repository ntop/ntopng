--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local db_utils = require "db_utils"
local data_retention_utils = require "data_retention_utils"

-- ########################################################

function cleanup_clickhouse_logs()
   local ch_dir = dirs.workingdir.."/tmp/clickhouse"
   local os_utils = require "os_utils"
   
   -- Delete discards older than 3 days
   os_utils.execWithOutput("find "..ch_dir.." -name \"*.dsc\" -type f -mtime +3 -exec rm -f {} +")

   -- Delete tmp older than 1 day
   os_utils.execWithOutput("find "..ch_dir.." -name \"*.tmp\" -type f -mtime +1 -exec rm -f {} +")
end

-- ########################################################

if(not ntop.isWindows()) then
   if ntop.isClickHouseEnabled() then
      local data_retention = data_retention_utils.getDataRetentionDays()
      local mysql_retention = os.time() - 86400 * data_retention
      
      db_utils.clickhouseDeleteOldPartitions(mysql_retention)
      
      -- Delete old discard files
      cleanup_clickhouse_logs()
   end
end

