--
-- (C) 2013-23 - ntop.org
--
-- This script is used to perform activities that are low
-- priority with respect to second.lua but that require
-- near realtime execution.
-- This script is executed every 3 seconds
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local scripts_triggers = require "scripts_triggers"

-- io.write("housekeeping.lua ["..os.time().."]\n")

-- Run this script for a minute before quitting (this reduces load on Lua VM infrastructure)
local periodicity = 3
local num_runs = 60 / periodicity
local sleep_duration = periodicity * 1000

for i=1,num_runs do
   if(ntop.isShutdown()) then break end

   local now = os.time()

   -- Check and possibly reload changed preferences
   if(scripts_triggers.arePrefsChanged()) then
      local prefs_reload_utils = require "prefs_reload_utils"
      
      prefs_reload_utils.check_reload_prefs()
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

   ntop.msleep(sleep_duration)
end
