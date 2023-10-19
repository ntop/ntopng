--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local rest_utils = require("rest_utils")
local host_alert_store = require "host_alert_store".new()
local auth = require "auth"
local alert_entities = require "alert_entities"
local alert_consts = require "alert_consts"

--
-- Read alerts data
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1", "status": "historical"}' http://localhost:3000/lua/rest/v1/get/alert/data.lua
--
-- status is currently mapped to the new alerts engine as below:
-- - engaged: host alerts engaged
-- - historical: host alerts past
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]
local format = "json"
local epoch_begin = _GET["epoch_begin"]
local epoch_end = _GET["epoch_end"]
local no_html = false

local what = _GET["status"]
local alert_type = _GET["alert_type"]
local alert_severity = _GET["alert_severity"]

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

if isEmptyString(what) then
   rc = rest_utils.consts.err.invalid_args
   rest_utils.answer(rc)
   return
end

local engaged = false
if what == "engaged" then
   engaged = true
   -- backwardcompatibility
   _GET["status"] = "engaged"
else
   _GET["status"] = "historical"
end

-- Fetch the results
local alerts, recordsFiltered

if((epoch_begin ~= nil) and (epoch_end ~= nil)) then
   epoch_begin = tonumber(epoch_begin)
   epoch_end   = tonumber(epoch_end)

   if(epoch_begin <= epoch_end) then
      host_alert_store:add_time_filter(epoch_begin, epoch_end)
   end
end

local entity = "host"

alerts, recordsFiltered, info = host_alert_store:select_request(nil, "*")

local alert_names = alert_consts.getAlertTypes(alert_entities[entity].entity_id)

for _, _value in ipairs(alerts or {}) do
   local formatted_val = host_alert_store:format_record(_value, no_html)
   local record = {}

   tprint("----")

   record["date"] = _value.tstamp_epoch
   record["duration"] = _value.duration
   record["score"] = _value.score
   record["severity"] = alert_consts.alertSeverityRaw(_value.severity)
   record["count"] = 1
   record["msg"] = formatted_val.msg.description
   record["type"] = alert_names[tonumber(_value.alert_id)]
   record["entity"] = entity
   record["entity_val"] = "" -- TODO

   res[#res + 1] = record
end

rest_utils.answer(rc, res)

