--
-- (C) 2021-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local auth = require "auth"
local rest_utils = require("rest_utils")
local host_alert_store = require "host_alert_store".new()

--
-- Read alerts data
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v1/get/host/alert/list.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]
local format = _GET["format"] or "json"
local no_html = (format == "txt")

if not auth.has_capability(auth.capabilities.alerts) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)

-- Fetch the results
local alerts, recordsFiltered = host_alert_store:select_request()

for _, _value in ipairs(alerts or {}) do
   res[#res + 1] = host_alert_store:format_record(_value, no_html)
end

if no_html then
   res = host_alert_store:to_csv(res)
   rest_utils.vanilla_payload_response(rc, res, "text/csv")
else
   rest_utils.extended_answer(rc, {records = res}, {
      ["draw"] = tonumber(_GET["draw"]),
      ["recordsFiltered"] = recordsFiltered,
      ["recordsTotal"] = #res
   }, format)
end

