--
-- (C) 2013-20 - ntop.org
--

--
-- This script is executed when ntopng shuts down when
-- network interfaces are setup
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local prefs_dump_utils = require "prefs_dump_utils"
local recovery_utils = require "recovery_utils"

require "lua_utils" -- NOTE: required by alert_utils
require "alert_utils"

local now = os.time()
local ifnames = interface.getIfNames()

notify_ntopng_stop()
prefs_dump_utils.savePrefsToDisk()

for _, ifname in pairs(ifnames) do
  interface.select(ifname)
  interface.releaseEngagedAlerts()
end

processAlertNotifications(now, 3 --[[ deadline ]], true --[[ force ]])

recovery_utils.mark_clean_shutdown()
