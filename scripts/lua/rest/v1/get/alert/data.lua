--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local alert_utils = require "alert_utils"
require "flow_utils"
local alert_consts = require "alert_consts"
local format_utils = require "format_utils"
local json = require "dkjson"
local rest_utils = require("rest_utils")
local graph_utils = nil


if ntop.isPro() then
   graph_utils = require "graph_utils"
end

--
-- Read alerts data
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1", "status": "historical"}' http://localhost:3000/lua/rest/v1/get/alert/data.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]
local what = _GET["status"]
local epoch_begin = _GET["epoch_begin"]
local epoch_end = _GET["epoch_end"]
local alert_type = _GET["alert_type"]
local alert_severity = _GET["alert_severity"]

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
end

local alert_options = _GET

local alerts = alert_utils.getAlerts(what, alert_options)

if alerts == nil then alerts = {} end

for _key,_value in ipairs(alerts) do
   local record = {}
   local alert_entity
   local alert_entity_val

   if _value["alert_entity"] ~= nil then
      alert_entity    = alert_consts.alertEntityLabel(_value["alert_entity"], true)
   else
      alert_entity = "flow" -- flow alerts page doesn't have an entity
   end

   if _value["alert_entity_val"] ~= nil then
      alert_entity_val = _value["alert_entity_val"]
   else
      alert_entity_val = ""
   end

   local duration
   if engaged == true then
      duration = os.time() - tonumber(_value["alert_tstamp"])
   elseif tonumber(_value["alert_tstamp_end"]) ~= nil then
      duration = tonumber(_value["alert_tstamp_end"]) - tonumber(_value["alert_tstamp"])
   end

   local severity = alert_consts.alertSeverityRaw(tonumber(_value["alert_severity"]))
   local atype = alert_consts.alertTypeRaw(tonumber(_value["alert_type"]))
   local count    = tonumber(_value["alert_counter"])
   local score    = tonumber(_value["score"])
   local alert_info      = alert_utils.getAlertInfo(_value)
   local msg      = alert_utils.formatAlertMessage(ifid, _value, alert_info)
   local date = _value["alert_tstamp"]

   record["date"] = date
   record["duration"] = duration
   record["severity"] = severity
   record["type"] = atype
   record["count"] = count
   record["score"] = score
   record["msg"] = msg
   record["entity"] = alert_entity
   record["entity_val"] = alert_entity_val

   if(graph_utils and graph_utils.getAlertGraphLink) then
      record["drilldown"]  = graph_utils.getAlertGraphLink(ifid, _value, alert_info, engaged)
   end
   -- record["value"] = _value

   res[#res + 1] = record
	  
end -- for

rest_utils.answer(rc, res)

