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

require "lua_utils"
require "alert_utils"
local callback_utils = require "callback_utils"
local now = os.time()

check_mac_ip_association_alerts()
if ntop.isnEdge() then
   check_nfq_flushed_queue_alerts()
end
check_process_alerts()
callback_utils.uploadTSdata()

processAlertNotifications(now, 3)
