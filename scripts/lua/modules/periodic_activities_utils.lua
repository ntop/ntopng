--
-- (C) 2020-21 - ntop.org
--
-- This file contains the check constats

local periodic_activities_utils = {}

-- ###########################################

periodic_activities_utils.periodic_activities = {
   -- Can use this table to keep certain information for every periodic activity
   -- Keep in sync with PeriodicActivities.cpp
   ["stats_update.lua"]            = { max_duration =    10 },
   ["dequeue_flows_for_hooks.lua"] = { max_duration =  3600 },
   ["periodic_checks.lua"]   = { max_duration =    60 },
   ["minute.lua"]                  = { max_duration =    60 },
   ["5min.lua"]                    = { max_duration =   300 },
   ["hourly.lua"]                  = { max_duration =   600 },
   ["daily.lua"]                   = { max_duration =  3600 },
   ["housekeeping.lua"]            = { max_duration =     6 },
   ["discover.lua"]                = { max_duration =  3600 },
   ["timeseries.lua"]              = { max_duration =  3600 },
   ["second.lua"]                  = { max_duration =     2 },
}

-- ###########################################

periodic_activities_utils.periodic_activity_issues = {
   ["not_executed"] =
      {
	 i18n_title = "internals.script_not_executed",
	 i18n_descr = "internals.script_not_executed_descr"
      },
   ["is_slow"] =
      {
	 i18n_title = "internals.script_deadline_exceeded",
	 i18n_descr = "internals.script_deadline_exceeded_descr",
      },
   ["alerts_drops"] =
      {
	 i18n_title = "internals.alert_drops",
	 i18n_descr = "internals.alert_drops_descr"
      },
}

-- ###########################################

-- Returns true when at least one of the interfaces (system interface included)
-- has issues with one of its periodic activities
local function stats_have_degraded_performance(stats)
   for ps_name, ps_stats in pairs(stats) do
      -- The activity is slow if it has been executing for too long,
      -- if it has been waiting in the queue for too long (no available threads)
      -- of if the RRD writes are slow
      for k in pairs(periodic_activities_utils.periodic_activity_issues) do
         if ps_stats[k] then
            return true
         end
      end
   end
end

-- ###########################################

-- Check if any of the executing periodic activities is slow and showing
-- degraded performance
function periodic_activities_utils.have_degraded_performance()
   local cur_ifid = tostring(interface.getId())
   local res = false

   local available_interfaces = interface.getIfNames()
   -- Add the system interface id
   available_interfaces[getSystemInterfaceId()] = getSystemInterfaceName()

   for _, iface in pairs(available_interfaces) do
      interface.select(iface)

      if stats_have_degraded_performance(interface.getPeriodicActivitiesStats()) then
	 res = true
	 break
      end
   end

   -- Restore the original id and return
   interface.select(cur_ifid)

   return res
end

-- ###########################################

return periodic_activities_utils
