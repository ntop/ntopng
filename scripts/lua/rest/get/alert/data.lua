--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "alert_utils"
require "flow_utils"

local format_utils = require "format_utils"
local json = require "dkjson"

sendHTTPHeader('application/json')

local status = _GET["status"]

local engaged = false
if status == "engaged" then
   engaged = true
end

interface.select(ifname)

local alert_options = _GET

local function formatAlertRecord(alert_entity, record)
   local flow = ""
   local column_msg = record["alert_json"]

   if alert_entity == "flow" then
      column_msg = formatRawFlow(record, record["alert_json"])
   elseif alert_entity == "User" then
      column_msg = formatRawUserActivity(record, record["alert_json"])
   end

   column_msg = string.gsub(column_msg, '"', "'")

   return column_msg
end

local alerts = getAlerts(status, alert_options)

if alerts == nil then alerts = {} end

local result = {}

for _key,_value in ipairs(alerts) do
   local record = {}
   local alert_entity
   local alert_entity_val

   if _value["alert_entity"] ~= nil then
      alert_entity    = alertEntityLabel(_value["alert_entity"], true)
   else
      alert_entity = "flow" -- flow alerts page doesn't have an entity
   end

   if _value["alert_entity_val"] ~= nil then
      alert_entity_val = _value["alert_entity_val"]
   else
      alert_entity_val = ""
   end

   local column_duration
   if engaged == true then
      column_duration = os.time() - tonumber(_value["alert_tstamp"])
   elseif tonumber(_value["alert_tstamp_end"]) ~= nil then
      column_duration = tonumber(_value["alert_tstamp_end"]) - tonumber(_value["alert_tstamp"])
   end

   local column_severity = alertSeverityLabel(tonumber(_value["alert_severity"]), true)
   local column_type     = alertTypeLabel(tonumber(_value["alert_type"]), true)
   local column_msg      = formatAlertRecord(alert_entity, _value) or ""
   local column_id = tostring(_value["rowid"])
   local column_date = _value["alert_tstamp"]

   record["key"] = column_id
   record["date"] = column_date
   record["duration"] = column_duration
   record["severity"] = column_severity
   record["type"] = column_type
   record["msg"] = column_msg
   record["entity"] = alert_entity
   record["entity_val"] = alert_entity_val

   result[#result + 1] = record
	  
end -- for

print(json.encode(result))

