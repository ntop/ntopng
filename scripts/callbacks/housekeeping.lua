--
-- (C) 2013-17 - ntop.org
--
-- This script is used to perform activities that are low
-- priority with respect to second.lua but that require
-- near realtime execution.
-- This script is executed every few seconds (default 3)
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "alert_utils"
require "slack_utils"

housekeepingAlertsMakeRoom()
sendSlackMessages()

tprint("purging")
package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
local host_pools_utils = require "host_pools_utils"
-- check and possibly purge expired captive portal members
host_pools_utils.purgeExpiredPoolsMembers()
