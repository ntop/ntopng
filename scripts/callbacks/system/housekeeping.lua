--
-- (C) 2013-19 - ntop.org
--
-- This script is used to perform activities that are low
-- priority with respect to second.lua but that require
-- near realtime execution.
-- This script is executed every 3 seconds
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "alert_utils"
local lists_utils = require "lists_utils"
local recording_utils = require "recording_utils"
local now = os.time()
local periodicity = 3

check_mac_ip_association_alerts()
if ntop.isnEdge() then
   check_nfq_flushed_queue_alerts()
end
check_host_remote_to_remote_alerts()
check_broadcast_domain_too_large_alerts()
check_process_alerts()
check_outside_dhcp_range_alerts()
check_periodic_activities_alerts()
lists_utils.checkReloadLists()

recording_utils.checkExtractionJobs()

processAlertNotifications(now, periodicity)
