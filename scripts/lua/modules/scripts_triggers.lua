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

function midnightStatsResetEnabled()
   if (ntop.getPref("ntopng.prefs.midnight_stats_reset_enabled") == "1") then
      return true
   end

   return false
end

-- ###########################################

function scripts_triggers.isDumbFlowToSQLEnabled(ifstats)
   if (ntop.getPrefs()["is_dump_flows_to_mysql_enabled"] and not ifstats.isViewed) then
      return true
   end

   return false
end

-- ###########################################

function scripts_triggers.isDeltaSet()
   if (ntop.getPref("ntopng.prefs.enable_ts_deltas_writes") == "1") then
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
   if ntop.getCache('ntopng.cache.force_reload_plugins') == '1' then
      return(true)
   else
      local demo_ends_at = ntop.getInfo()["pro.demo_ends_at"]
      local time_delta = demo_ends_at - when
      
      if demo_ends_at and demo_ends_at > 0 and time_delta <= 10 and ntop.isPro() and not ntop.hasPluginsReloaded() then
	 return(true)
      end
   end

   return(false)
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
