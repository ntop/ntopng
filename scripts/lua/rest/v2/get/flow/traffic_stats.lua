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
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/get/flow/traffic_stats.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--
local flows_filter = getFlowsFilter()
local rc = rest_utils.consts.success.ok
local res

local ifid = _GET["ifid"]

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)

-- This is used to get the current bytes rcvd and sent by these specific filters
res = interface.getActiveFlowsStats(flows_filter["hostFilter"], flows_filter, true)

rest_utils.answer(rc, res)
