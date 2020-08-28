--
-- (C) 2013-20 - ntop.org
--
-- This script is used to perform activities that are low
-- priority with respect to second.lua but that require
-- near realtime execution.
-- This script is executed every 3 seconds
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/recipients/?.lua;" .. package.path

require "lua_utils"
local lists_utils = require "lists_utils"
local recording_utils = require "recording_utils"
local plugins_utils = require "plugins_utils"
local recipients_lua_utils = require "recipients_lua_utils"

local now = os.time()

if(areAlertsEnabled()) then
   local alert_utils = require "alert_utils"
   local alerts_api = require "alerts_api"
   local periodicity = 3
  
   -- Check for alerts from the datapath
   alert_utils.checkStoreAlertsFromC()

   -- Check for alerts to be processed out of the recipients
   recipients_lua_utils.process_notifications()

   -- Check for alerts to be notified
   alert_utils.processAlertNotifications(now, periodicity)
end
   
-- Check and possibly reload plugins
plugins_utils.checkReloadPlugins(now)

lists_utils.checkReloadLists()

if recording_utils.isAvailable() then
  recording_utils.checkExtractionJobs()
end
