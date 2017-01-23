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

-- Scan "hour" alerts
for _, ifname in pairs(interface.getIfNames()) do
   scanAlerts("hour", ifname)
end

