--
-- (C) 2013-19 - ntop.org
--
-- This script is used to perform activities that are low
-- priority with respect to second.lua but that require
-- near realtime execution.
-- This script is executed every 3 seconds
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "alert_utils"
local alerts_api = require "alerts_api"
local lists_utils = require "lists_utils"
local recording_utils = require "recording_utils"
local now = os.time()
local periodicity = 3
local deadline = now + periodicity

alerts_api.checkPendingStoreAlerts(deadline)
checkStoreAlertsFromC(deadline)
lists_utils.checkReloadLists()

if recording_utils.isAvailable() then
  recording_utils.checkExtractionJobs()
end

processAlertNotifications(now, periodicity)
