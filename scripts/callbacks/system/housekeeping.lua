--
-- (C) 2013-21 - ntop.org
--
-- This script is used to perform activities that are low
-- priority with respect to second.lua but that require
-- near realtime execution.
-- This script is executed every 3 seconds
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local scripts_triggers = require "scripts_triggers"
local now = os.time()

-- Check and possibly reload changed preferences
if(scripts_triggers.arePrefsChanged()) then
   local prefs_reload_utils = require "prefs_reload_utils"
   
   prefs_reload_utils.check_reload_prefs()
end

-- Check and possibly reload plugins
if(scripts_triggers.checkReloadPlugins(now)) then
   local plugins_utils = require "plugins_utils"
   
   plugins_utils.checkReloadPlugins(now)
end

if(scripts_triggers.checkReloadLists()) then
   local lists_utils = require "lists_utils"
   
   lists_utils.checkReloadLists()
end
   
if scripts_triggers.isRecordingAvailable() then
   local recording_utils = require "recording_utils"
   
  recording_utils.checkExtractionJobs()
end

if ntop.isPro() and not ntop.isnEdge() then
   if  ntop.timeToRefreshIPSRules() then
      package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
      local policy_utils = require "policy_utils"

      policy_utils.broadcast_ips_rules()
   end
end
