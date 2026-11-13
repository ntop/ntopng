--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint"
require "ntop_utils" -- isAdministrator()
local rest_utils = require("rest_utils")

--
-- Flows created per day, extrapolated from the flows counted since startup
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/ntopng/flow_storage_estimate.lua
--

if not isAdministrator() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

local SECONDS_PER_DAY = 86400
local uptime = ntop.getUptime()
local new_flows = 0

for ifid, _ in pairs(interface.getIfNames()) do
    interface.select(ifid)
    new_flows = new_flows + interface.getStats().stats.new_flows
end

rest_utils.answer(rest_utils.consts.success.ok, {
    uptime = uptime,
    flows_per_day = math.floor(new_flows / uptime * SECONDS_PER_DAY)
})
