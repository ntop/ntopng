--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local rest_utils = require("rest_utils")
local alert_store_utils = require "alert_store_utils"
local flow_alert_store = require "flow_alert_store".new()
local alert_entities = require "alert_entities"
local alert_store_instances = alert_store_utils.all_instances_factory()
local auth = require "auth"

--
-- Read alerts data
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/flow/alert/alert_details.lua?ifid=1&status=historical&row_id=1&tstamp=1700000000"
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--
local rc = rest_utils.consts.success.ok
local res = {}
local alert = nil
local ifid = _GET["ifid"]
local row_id = _GET["row_id"]
local tstamp = _GET["tstamp"]

if not auth.has_capability(auth.capabilities.alerts) then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

if not ifid or not tonumber(row_id) or not tstamp then
    rest_utils.answer(rest_utils.consts.err.invalid_args)
    return
end

-- interface.select silently falls back to an allowed interface: check it
interface.select(ifid)
if tostring(interface.getId()) ~= tostring(ifid) then
    rest_utils.answer(rest_utils.consts.err.invalid_interface)
    return
end

if alert_entities["flow"] then
    local alert_store_instance = alert_store_instances[alert_entities["flow"].alert_store_name]

    if alert_store_instance then
        local alerts, _ = alert_store_instance:select_request(nil, "*")
        if #alerts >= 1 then
            alert = alerts[1]
            -- formatted_alert = alert_store_instance:format_record(alert, false)
            res = alert_store_instance:get_alert_details(alert)
        end
    end
end

rest_utils.answer(rc, res)
