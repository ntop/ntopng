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

require "lua_utils"
local lists_utils = require "lists_utils"
local recording_utils = require "recording_utils"
local plugins_utils = require "plugins_utils"
local now = os.time()



if(areAlertsEnabled()) then
   local notification_recipients = require "notification_recipients"
   local periodicity = 3

   notification_recipients.process_notifications(now, periodicity)
end

-- Check and possibly reload plugins
plugins_utils.checkReloadPlugins(now)

lists_utils.checkReloadLists()

if recording_utils.isAvailable() then
  recording_utils.checkExtractionJobs()
end
