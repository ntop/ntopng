--
-- (C) 2014-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path


local DEFAULT_DATA_RETENTION_DAYS = 30
local DATA_RETENTION_DAYS_KEY = "ntopng.prefs.data_retention_days"

local data_retention_utils = {}

-- ########################################################

function data_retention_utils.getDefaultRetention()
   return DEFAULT_DATA_RETENTION_DAYS
end

-- ########################################################

function data_retention_utils.getDataRetentionDays()
   local data_retention = ntop.getCache(DATA_RETENTION_DAYS_KEY)

   return tonumber(data_retention) or data_retention_utils.getDefaultRetention()
end

-- ########################################################

return data_retention_utils
