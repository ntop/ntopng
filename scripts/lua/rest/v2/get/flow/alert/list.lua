--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local rest_utils = require("rest_utils")
local flow_alert_store = require "flow_alert_store".new()
local auth = require "auth"

--
-- Read alerts data
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/get/flow/alert/list.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]
local format = _GET["format"] or "json"
local epoch_begin = _GET["epoch_begin"]
local epoch_end   = _GET["epoch_end"]
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
local alerts, recordsFiltered

if((epoch_begin ~= nil) and (epoch_end ~= nil)) then
   epoch_begin = tonumber(epoch_begin)
   epoch_end   = tonumber(epoch_end)

   if(epoch_begin <= epoch_end) then
      flow_alert_store:add_time_filter(epoch_begin, epoch_end)
   end
end

alerts, recordsFiltered, info = flow_alert_store:select_request(nil, "*")

for _, _value in ipairs(alerts or {}) do
   res[#res + 1] = flow_alert_store:format_record(_value, no_html)
end

if no_html then
   res = flow_alert_store:to_csv(res)   
   rest_utils.vanilla_payload_response(rc, res, "text/csv")
else
   local data = {
      records = res,
      stats = info,
   }

   rest_utils.extended_answer(rc, data, {
      ["draw"] = tonumber(_GET["draw"]),
      ["recordsFiltered"] = recordsFiltered,
      ["recordsTotal"] = #res
   }, format)
end
