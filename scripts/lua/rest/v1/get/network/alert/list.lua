--
-- (C) 2021-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local rest_utils = require("rest_utils")
local network_alert_store = require "network_alert_store".new()

--
-- Read alerts data
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v1/get/network/alert/list.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)

-- Fetch the results
local alerts, recordsFiltered = network_alert_store:select_request()

for _key,_value in ipairs(alerts or {}) do
   local record = network_alert_store:format_record(_value)
   res[#res + 1] = record
end -- for

rest_utils.extended_answer(rc, {records = res}, {
			      ["draw"] = tonumber(_GET["draw"]),
			      ["recordsFiltered"] = recordsFiltered,
			      ["recordsTotal"] = #res
})
