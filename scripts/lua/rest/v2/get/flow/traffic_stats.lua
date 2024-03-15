--
-- (C) 2013-24 - ntop.org
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
local application = _GET["application"]
if not isEmptyString(application) then
    if string.starts(application, "cat_") then
        local category = split(application, "cat_")
        _GET["category"] = category[2]
        _GET["application"] = nil
    end
end
local flows_filter = getFlowsFilter()
local rc = rest_utils.consts.success.ok
local res

local ifid = _GET["ifid"]

local host = _GET["host"]
local talking_with = _GET["talkingWith"]
local client = _GET["client"]
local server = _GET["server"]
local flow_info = _GET["flow_info"]
local application = _GET["application"]
if not isEmptyString(application) then
    if string.starts(application, "cat_") then
        local category = split(application, "cat_")
        _GET["category"] = category[2]
        _GET["application"] = nil
    end
end
local flows_filter = getFlowsFilter()
-- This is used to get the current bytes rcvd and sent by these specific filters
local stats = interface.getActiveFlowsStats(host, flows_filter, false, talking_with, client, server, flow_info)
res = {
   totBytesSent = stats.totBytesSent,
   totBytesRcvd = stats.totBytesRcvd
}

rest_utils.answer(rc, res)
