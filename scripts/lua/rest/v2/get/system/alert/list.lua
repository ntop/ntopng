--
-- (C) 2021-21 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local format_utils = require "format_utils"
local alert_utils = require "alert_utils"
local alert_consts = require "alert_consts"
local alert_entities = require "alert_entities"
local rest_utils = require("rest_utils")
local system_alert_store = require"system_alert_store".new()
local auth = require "auth"

--
-- Read alerts data
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/get/system/alert/list.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local format = _GET["format"] or "json"
local no_html = (format == "txt")
local download = false

if ntop.isClickHouseEnabled() and no_html then
    download = true
end

if not auth.has_capability(auth.capabilities.alerts) then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

interface.select(getSystemInterfaceId())

if not download then
    local alerts, recordsFiltered, info = system_alert_store:select_request(nil, "*")

    for _, _value in ipairs(alerts or {}) do
        res[#res + 1] = system_alert_store:format_record(_value, no_html)
    end

    if no_html then
        res = system_alert_store:to_csv(res)
        rest_utils.vanilla_payload_response(rc, res, "text/csv")
    else
        local data = {
            records = res,
            stats = info
        }

        rest_utils.extended_answer(rc, data, {
            ["draw"] = tonumber(_GET["draw"]),
            ["recordsFiltered"] = recordsFiltered,
            ["recordsTotal"] = recordsFiltered
        }, format)
    end
else
    local extra_headers = {}
    local rsp = "" -- data pushed by the query function clickhouse_utils.query (clickhouse_utils.lua)

    extra_headers["Content-Disposition"] = "attachment;filename=\"system_alerts_export_" .. os.time() .. ".csv\""
    rest_utils.vanilla_payload_response(rest_utils.consts.success.ok, rsp, "application/octet-stream", extra_headers)
    system_alert_store:select_request(nil, "*", download)
end
