--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- ########################################################

local prefs = ntop.getPrefs()

-- ########################################################

-- when the active local hosts cache is enabled, ntopng periodically dumps active local hosts statistics to redis
-- in order to protect from failures (e.g., power losses)
if prefs.is_active_local_hosts_cache_enabled then
   local interval = prefs.active_local_hosts_cache_interval
   local when = os.time()
   local diff = when % tonumber((interval or 3600 --[[ default 1 h --]]))

   if diff < 60 then
      -- to protect from failures (e.g., power losses) it is possible to save
      -- local hosts counters to redis once per hour
      interface.dumpLocalHosts2redis()
   end
end
