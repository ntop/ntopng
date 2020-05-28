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
local epoch_begin = _GET["epoch_begin"]
local epoch_end = _GET["epoch_end"]
local alert_type = _GET["alert_type"]
local alert_severity = _GET["alert_severity"]

if isEmptyString(ifid) then
   rc = rest_utils.consts_invalid_interface
   print(rest_utils.rc(rc))
   return
end

interface.select(ifid)

if isEmptyString(what) then
   rc = rest_utils.consts_invalid_args
   print(rest_utils.rc(rc))
   return
end

local engaged = false
if what == "engaged" then
   engaged = true
end

local alert_options = {
   epoch_begin = epoch_begin,
   epoch_end = epoch_end,
   alert_type = alert_type,
   alert_severity = alert_severity,
}

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

   local severity = alert_consts.alertSeverityLabel(tonumber(_value["alert_severity"]), true)
   local atype = alert_consts.alertTypeLabel(tonumber(_value["alert_type"]), true)
   local count    = tonumber(_value["alert_counter"])
   local score    = tonumber(_value["score"])
   local alert_info      = alert_utils.getAlertInfo(_value)
   local msg      = alert_utils.formatAlertMessage(ifid, _value, alert_info)
   local id = tostring(_value["rowid"])
   local date = _value["alert_tstamp"]

   record["key"] = id
   record["date"] = date
   record["duration"] = duration
   record["severity"] = severity
   record["type"] = atype
   record["count"] = count
   record["score"] = score
   record["msg"] = msg
   record["entity"] = alert_entity
   record["entity_val"] = alert_entity_val
   -- record["value"] = _value

   res[#res + 1] = record
	  
end -- for

print(rest_utils.rc(rc, res))

