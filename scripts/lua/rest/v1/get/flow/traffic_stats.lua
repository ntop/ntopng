--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "flow_utils"
require "lua_utils"
local rest_utils = require("rest_utils")

--
-- Read list of active flows
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v1/get/flow/traffic_stats.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--
local flows_filter = getFlowsFilter()
local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)

-- This is used to get the current bytes rcvd and sent by these specific filters
filtered_traffic_stats = interface.getFlowsTrafficStats(flows_filter["hostFilter"], flows_filter, true)

res["throughput_bps_sent"] = (filtered_traffic_stats["flows"]["totNewBytesSent"] - filtered_traffic_stats["flows"]["totOldBytesSent"]) / 5

res["throughput_bps_rcvd"] = (filtered_traffic_stats["flows"]["totNewBytesRcvd"] - filtered_traffic_stats["flows"]["totOldBytesRcvd"]) / 5

if res["throughput_bps_sent"] < 0 then
   res["throughput_bps_sent"] = 0
end

if res["throughput_bps_rcvd"] < 0 then
   res["throughput_bps_rcvd"] = 0
end

rest_utils.answer(rc, res)
