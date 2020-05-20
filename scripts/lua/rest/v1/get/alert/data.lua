--
-- (C) 2013-20 - ntop.org
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

--
-- Read alerts data
-- Example: curl -u admin:admin -d '{"ifid": "1", "status": "historical"}' http://localhost:3000/lua/rest/v1/get/alert/data.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

sendHTTPHeader('application/json')

local rc = rest_utils.consts_ok
local res = {}

local ifid = _GET["ifid"]
local what = _GET["status"]

if isEmptyString(ifid) then
   rc = rest_utils.consts_invalid_interface
   print(rest_utils.rc(rc))
   return
end

if isEmptyString(what) then
   rc = rest_utils.consts_invalid_args
   print(rest_utils.rc(rc))
   return
end

-- interface.select(ifid)

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

   local column_duration
   if engaged == true then
      column_duration = os.time() - tonumber(_value["alert_tstamp"])
   elseif tonumber(_value["alert_tstamp_end"]) ~= nil then
      column_duration = tonumber(_value["alert_tstamp_end"]) - tonumber(_value["alert_tstamp"])
   end

   local column_severity = alert_consts.alertSeverityLabel(tonumber(_value["alert_severity"]), true)
   local column_type     = alert_consts.alertTypeLabel(tonumber(_value["alert_type"]), true)
   local column_msg      = alert_utils.formatAlertMessage(ifid, _value)
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
   -- record["value"] = _value

   res[#res + 1] = record
	  
end -- for

print(rest_utils.rc(rc, res))

