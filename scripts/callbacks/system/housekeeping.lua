--
-- (C) 2013-18 - ntop.org
--
-- This script is used to perform activities that are low
-- priority with respect to second.lua but that require
-- near realtime execution.
-- This script is executed every few seconds (default 3)
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "slack_utils"
require "lua_utils"
require "alert_utils"

local prefs_dump_utils = require "prefs_dump_utils"
sendSlackMessages()

local prefs_changed = ntop.getCache("ntopng.prefs_changed")

if(prefs_changed == "true") then
   -- First delete prefs_changed then dump data
   ntop.delCache("ntopng.prefs_changed")
   prefs_dump_utils.savePrefsToDisk()
end

check_mac_ip_association_alerts()
