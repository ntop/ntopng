--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local alert_utils = require "alert_utils"

local callback_utils = require "callback_utils"
local db_utils = require "db_utils"
local ts_utils = require "ts_utils"
local data_retention_utils = require "data_retention_utils"
local user_scripts = require("user_scripts")

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

user_scripts.schedulePeriodicScripts("day")

local data_retention = data_retention_utils.getDataRetentionDays()

ntop.deleteMinuteStatsOlderThan(interface_id, data_retention)

if ntop.getPrefs()["is_dump_flows_to_mysql_enabled"] and not ifstats.isViewed then
   local mysql_retention = os.time() - 86400 * data_retention
   db_utils.harverstExpiredMySQLFlows(_ifname, mysql_retention, verbose)
end

ts_utils.deleteOldData(interface_id)

-- Deletes old alerts; alerts older then, by default, 365 days ago
alert_utils.deleteOldData(interface_id, os.time() - (86500 * tonumber(prefs.max_num_days_before_delete_alert)))
alert_utils.optimizeAlerts()
