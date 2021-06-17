--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local scripts_triggers = require "scripts_triggers"
local ts_utils         = require "ts_utils"
local data_retention_utils = require "data_retention_utils"

local prefs            = ntop.getPrefs() or nil

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/callbacks/interface/?.lua;" .. package.path
   require('daily')
end

-- ########################################################

local verbose = ntop.verboseTrace()
local ifstats = interface.getStats()
local _ifname = ifstats.name

-- ########################################################

local interface_id = getInterfaceId(_ifname)

-- Setting up periodic checks
local k = string.format("ntopng.cache.ifid_%i.checks.request.granularity_day", interface.getId())
ntop.setCache(k, "1")

local data_retention = data_retention_utils.getDataRetentionDays()

-- ###########################################

if scripts_triggers.isDumbFlowToSQLEnabled(ifstats) then
   local db_utils = require "db_utils"

   local mysql_retention = os.time() - 86400 * data_retention
   db_utils.harverstExpiredMySQLFlows(_ifname, mysql_retention, verbose)
end

-- ###########################################

ntop.deleteMinuteStatsOlderThan(interface_id, data_retention)
ts_utils.deleteOldData(interface_id)
