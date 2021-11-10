--
-- (C) 2014-21 - ntop.org
--
-- Absolutely don't put require inside this file.
-- It is born to do fast checks, to avoid slowing down
-- periodics checks and callbacks.
--

scripts_triggers = {}


-- ###########################################

function scripts_triggers.aggregateHttp()
   if (ntop.getCache("ntopng.prefs.http_traffic_dump")) then
      return true
   end

   return false
end
   
-- ###########################################

function scripts_triggers.midnightStatsResetEnabled()
   if (ntop.getPref("ntopng.prefs.midnight_stats_reset_enabled") == "1") then
      return true
   end

   return false
end

-- ###########################################

function scripts_triggers.isDumpFlowToSQLEnabled(ifstats)
   local prefs = ntop.getPrefs()

   if prefs["is_dump_flows_to_mysql_enabled"] or prefs["is_dump_flows_to_clickhouse_enabled"] then
      return true
   end

   return false
end

-- ###########################################

function scripts_triggers.isRecordingAvailable()
   local is_available_key = "ntopng.cache.traffic_recording_available"
   if(ntop.isAdministrator() and (ntop.getCache(is_available_key) == "1")) then
      return true
   end
   
   return false
end

-- ###########################################

function scripts_triggers.isRrdCreationEnabled()
   if(ntop.getPref("ntopng.prefs.internals_rrd_creation") == "1") then
      return true
   end
   
   return false
end

-- ###########################################

function scripts_triggers.isRrdInterfaceCreation()
   if(ntop.getPref("ntopng.prefs.interface_rrd_creation") ~= "0") then
      return true
   end
   
   return false
end

-- ###########################################

function scripts_triggers.hasHighResolutionTs()
   local active_driver = ntop.getPref("ntopng.prefs.timeseries_driver")

   -- High resolution timeseries means dumping the host timeseries
   -- every 60 seconds instead of 300 seconds.
   return((active_driver == "influxdb") and
	 (ntop.getPref("ntopng.prefs.ts_resolution") ~= "300"))
end

-- ###########################################

function scripts_triggers.checkReloadLists()
   if((ntop.getCache("ntopng.cache.download_lists_utils") == "1") or (ntop.getCache("ntopng.cache.reload_lists_utils") == "1")) then
      return(true)
   else
      return(false)
   end
end

-- ###########################################

function scripts_triggers.checkReloadPlugins(when)
   local demo_ends_at = ntop.getInfo()["pro.demo_ends_at"]
   local time_delta = demo_ends_at - when
   local plugins_reloaded = false

   -- tprint({time_delta = time_delta, demo_ends_at = demo_ends_at, when = when, is_pro = ntop.isPro()})

   if ntop.getCache('ntopng.cache.force_reload_plugins') == '1' then
      -- Check and possibly reload plugins after a user has changed (e.g., applied or removed) a license
      -- from the web user interface (page about.lua)
      local plugins_utils = require "plugins_utils"
      ntop.delCache('ntopng.cache.force_reload_plugins')
      plugins_utils.loadPlugins(not ntop.isPro() --[[ reload only community if license is not pro --]])
      plugins_reloaded = true
   elseif demo_ends_at and demo_ends_at > 0 and time_delta <= 10 and ntop.isPro() and not ntop.hasPluginsReloaded() then
      -- Checks and possibly reload plugins for demo licenses. In case of demo licenses,
      -- if within 10 seconds from the license expirations, a plugin reload is executed only for the community plugins
      local plugins_utils = require "plugins_utils"
      plugins_utils.loadPlugins(true --[[ reload only community plugins --]])
      plugins_reloaded = true
   end

   if plugins_reloaded then
      ntop.reloadPlugins()
   end
end

-- ###########################################

function scripts_triggers.arePrefsChanged()
   local prefs_changed_key = "ntopng.cache.prefs_changed"
   
   if(ntop.getCache(prefs_changed_key) == "1") then
      return(true)
   else
      return(false)
   end
end
      
-- ###########################################

return scripts_triggers
