--
-- (C) 2014-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path


local DEFAULT_DATA_RETENTION_DAYS = 30
local DEFAULT_DATA_RETENTION_DAYS_KEY = "ntopng.prefs.data_retention_days"
local FLOWS_AND_ALERTS_DATA_RETENTION_DAYS_KEY = "ntopng.prefs.flows_and_alerts_data_retention_days"
local TS_AND_STATS_DATA_RETENTION_DAYS_KEY = "ntopng.prefs.ts_and_stats_data_retention_days"

local data_retention_utils = {}

-- ########################################################

function data_retention_utils.getDefaultRetention()
  return DEFAULT_DATA_RETENTION_DAYS
end

-- ########################################################

function data_retention_utils.getFlowsAndAlertsDataRetentionDays()
  local data_retention = ntop.getCache(FLOWS_AND_ALERTS_DATA_RETENTION_DAYS_KEY) or ntop.getCache(DEFAULT_DATA_RETENTION_DAYS_KEY) 

  return tonumber(data_retention) or data_retention_utils.getDefaultRetention()
end

-- ########################################################

function data_retention_utils.getTSAndStatsDataRetentionDays()
  local data_retention = ntop.getCache(TS_AND_STATS_DATA_RETENTION_DAYS_KEY) or ntop.getCache(DEFAULT_DATA_RETENTION_DAYS_KEY) 

  return tonumber(data_retention) or data_retention_utils.getDefaultRetention()
end

-- ########################################################

return data_retention_utils
