--
-- (C) 2013-25 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local rest_utils = require("rest_utils")
local alert_store_utils = require "alert_store_utils"
local flow_alert_store = require "flow_alert_store".new()
local alert_entities = require "alert_entities"
local alert_store_instances = alert_store_utils.all_instances_factory()

--
-- Read alerts data
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/get/flow/alert/alert_details.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--
local rc = rest_utils.consts.success.ok
local res = {}
local alert = nil
local row_id = _GET["row_id"]
local tstamp = _GET["tstamp"]

if row_id and tstamp and alert_entities["flow"] then
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
