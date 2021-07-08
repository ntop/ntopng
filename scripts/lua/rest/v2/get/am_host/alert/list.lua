--
-- (C) 2021-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local rest_utils = require("rest_utils")
local am_alert_store = require "am_alert_store".new()
local auth = require "auth"

--
-- Read alerts data
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{ }' http://localhost:3000/lua/rest/v2/get/am/alert/list.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--
local format = _GET["format"] or "json"
local no_html = (format == "txt")

local rc = rest_utils.consts.success.ok
local res = {}

if not auth.has_capability(auth.capabilities.alerts) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- Active monitoring stay in the system interface
interface.select(getSystemInterfaceId())

-- Fetch the results
local alerts, recordsFiltered = am_alert_store:select_request()

for _key,_value in ipairs(alerts or {}) do
   local record = am_alert_store:format_record(_value, no_html)
   res[#res + 1] = record
end -- for

if no_html then
   res = am_alert_store:to_csv(res)   
   rest_utils.vanilla_payload_response(rc, res, "text/csv")
else
   rest_utils.extended_answer(rc, {records = res}, {
				 ["draw"] = tonumber(_GET["draw"]),
				 ["recordsFiltered"] = recordsFiltered,
				 ["recordsTotal"] = #res
						   }, format)
end
