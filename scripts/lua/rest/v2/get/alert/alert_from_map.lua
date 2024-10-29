--
-- (C) 2021-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local alert_utils = require "alert_utils"
local json = require "dkjson"
local rest_utils = require "rest_utils"

-- Given alerts bitmap and alert_id return all the alerts relevant for the provided values
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"alert_map": "10050000000100000000100000", "alert_type": "90"}' http://localhost:3000/lua/rest/v2/get/alert/alert_from_map.lua
-- Returns: {"rsp":{"additional_alerts":["TCP Connection Refused ","TCP No Data Exchanged ","Periodic Flow ","TCP Flow Reset "],"alerts_by_score":[]},"rc_str":"OK","rc":0,"rc_str_hr":"Success"}


local rc = rest_utils.consts.success.ok
local alerts_map = _GET["alert_map"]
local alert_id = _GET["alert_type"]
local res 

if alerts_map and alert_id then
    local other_alerts_by_score, additional_alerts = alert_utils.format_other_alerts(tostring(alerts_map), tostring(alert_id), nil, nil, true)
    res = {
        alerts_by_score = alerts_by_score or {},
        additional_alerts = additional_alerts or {}
    }
else 
    rc = rest_utils.consts.err.invalid_args
    res = {}
end

rest_utils.answer(rc, res)
