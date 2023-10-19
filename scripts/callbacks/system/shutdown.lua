--
-- (C) 2013-23 - ntop.org
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
local alert_utils = require "alert_utils"
local alerts_api = require "alerts_api"
local recipients = require "recipients"
local checks = require "checks"
local periodicity = 3

local now = os.time()
local ifnames = interface.getIfNames()

-- io.write("shutdown.lua ["..os.time().."]\n")

alert_utils.notify_ntopng_stop()

-- Check and possibly dump preferences to disk
prefs_dump_utils.check_dump_prefs_to_disk()

for _, ifname in pairs(ifnames) do
  interface.select(ifname)
  -- Release all alerts
  alerts_api.releaseAllAlerts()
end

recipients.process_notifications(now, now + 1000 --[[ deadline ]], 3 --[[ periodicity ]], true)

-- Unload all checks
checks.loadUnloadUserScripts(false --[[ unload --]])

recovery_utils.mark_clean_shutdown()
