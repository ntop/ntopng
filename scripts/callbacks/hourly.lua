--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "alert_utils"

if (ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
  require("hourly")
end


local active_local_host_cache_enabled = ntop.getCache("ntopng.prefs.is_active_local_host_cache_enabled")

-- Scan "hour" alerts
for _, ifname in pairs(interface.getIfNames()) do
   scanAlerts("hour", ifname)


   if active_local_host_cache_enabled == "1" then
      -- to protect from failures (e.g., power losses) it is possible to save
      -- local hosts counters to redis once per hour
      interface.select(ifname)
      interface.dumpLocalHosts2redis()
   end

end

