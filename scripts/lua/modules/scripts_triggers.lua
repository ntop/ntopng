--
-- (C) 2014-21 - ntop.org
--

scripts_triggers = {}

-- ###########################################

function scripts_triggers.isRecordingAvailable()
   local is_available_key = "ntopng.cache.traffic_recording_available"
   
   if(ntop.isAdministrator() and (ntop.getCache(is_available_key) == "1")) then
      return true
   end
   
   return false
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
