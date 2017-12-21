--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "alert_utils"
require "flow_utils"

local json = require "dkjson"

sendHTTPContentTypeHeader('text/html')

local status          = _GET["status"]

local engaged = false
if status == "engaged" then
   engaged = true
end

interface.select(ifname)

if(tonumber(_GET["currentPage"]) == nil) then _GET["currentPage"] = 1 end
if(tonumber(_GET["perPage"]) == nil) then _GET["perPage"] = getDefaultTableSize() end

if(isEmptyString(_GET["sortColumn"]) or (_GET["sortColumn"] == "column_")) then
   _GET["sortColumn"] = getDefaultTableSort("alerts")
elseif((_GET["sortColumn"] ~= "column_") and (_GET["sortColumn"] ~= "")) then
   tablePreferences("sort_alerts", _GET["sortColumn"])
end

if _GET["sortOrder"] == nil then
   _GET["sortOrder"] = getDefaultTableSortOrder("alerts")
elseif((_GET["sortColumn"] == "column_") or (_GET["sortOrder"] == "")) then
   _GET["sortOrder"] = "asc"
end
tablePreferences("sort_order_alerts", _GET["sortOrder"])

local alert_options = _GET

local num_alerts = tonumber(_GET["totalRows"])
if num_alerts == nil then
   num_alerts = getNumAlerts(status, alert_options)
end

local function record_to_description(alert_entity, record)
   -- pretend record is a flow to reuse getFlowLabel
   local flow = ""
   if alert_entity == "flow" then
      flow = {
	 ["cli.ip"] = record["cli_addr"], ["cli.port"] = tonumber(record["cli_port"]),
	 ["cli.blacklisted"] = record["cli_blacklisted"] == "1",
	 ["srv.ip"] = record["srv_addr"], ["srv.port"] = tonumber(record["srv_port"]),
	 ["srv.blacklisted"] = record["srv_blacklisted"] == "1",
	 ["vlan"] = record["vlan_id"]}

      local l7proto_name = interface.getnDPIProtoName(tonumber(record["l7_proto"]) or 0)

      flow = "["..i18n("flow")..": "..(getFlowLabel(flow, false, true) or "").."] "

      if not isEmptyString(l7proto_name) then
	 flow = flow.."["..i18n("application")..": <A HREF='"..ntop.getHttpPrefix().."/lua/hosts_stats.lua?protocol="..record["l7_proto"].."'> " ..l7proto_name.."</A>] "
      end
   end

   local column_msg      = json.decode(record["alert_json"])
   if column_msg == nil then
      column_msg = string.gsub(record["alert_json"], '"', "'")
   else
      -- render the json
      local msg = ""
      if not isEmptyString(record["flow_status"]) then
	 msg = msg..getFlowStatus(tonumber(record["flow_status"])).." "
      end
      if not isEmptyString(flow) then
	 msg = msg..flow.." "
      end
      if not isEmptyString(column_msg["info"]) then
	 msg = msg.."["..i18n("info")..": "..column_msg["info"].."] "
      end
      column_msg = msg
   end

   return column_msg
end

local alerts = getAlerts(status, alert_options)

if alerts == nil then alerts = {} end

local res_formatted = {}

for _key,_value in ipairs(alerts) do
   local record = {}
   local alert_entity
   local alert_entity_val
   local column_duration = "-"
   local tdiff = os.time()-_value["alert_tstamp"]
   local column_date = os.date("%c", _value["alert_tstamp"])

   local alert_id        = _value["rowid"]

   if _value["alert_entity"] ~= nil then
      alert_entity    = alertEntityLabel(_value["alert_entity"])
   else
      alert_entity = "flow" -- flow alerts page doesn't have an entity
   end

   if _value["alert_entity_val"] ~= nil then
      alert_entity_val = _value["alert_entity_val"]
   else
      alert_entity_val = ""
   end

   if(tdiff < 60) then
      column_date  = secondsToTime(tdiff).." ago"
   end

   if engaged == true then
      column_duration = secondsToTime(os.time() - tonumber(_value["alert_tstamp"]))
   elseif tonumber(_value["alert_tstamp_end"]) ~= nil then
      column_duration = secondsToTime(tonumber(_value["alert_tstamp_end"]) - tonumber(_value["alert_tstamp"]))
   end

   local column_severity = alertSeverityLabel(tonumber(_value["alert_severity"]))
   local column_type     = alertTypeLabel(tonumber(_value["alert_type"]))

   local column_msg      = record_to_description(alert_entity, _value) or ""

   local column_id = tostring(alert_id)

   if ntop.isEnterprise() and (status == "historical-flows") then
      local explore = function()
	 local url = ntop.getHttpPrefix() .. "/lua/pro/enterprise/flow_alerts_explorer.lua?"
	 local origin = _value["cli_addr"]
	 local target = _value["srv_addr"]
	 if origin ~= nil and origin ~= "" then
	    url = url..'&origin='..origin
	 end
	 if target ~= nil and target ~= "" then
	    url = url..'&target='..target
	 end
	 if _value["alert_tstamp"] ~= nil then
	    url = url..'&epoch_begin='..(tonumber(_value["alert_tstamp"]) - 1800)
	    url = url..'&epoch_end='..(tonumber(_value["alert_tstamp"]) + 1800)
	 end
	 return url
      end
      column_id = column_id.."|"..explore()

   end

   record["column_key"] = column_id
   record["column_date"] = column_date
   record["column_duration"] = column_duration
   record["column_severity"] = column_severity
   record["column_type"] = column_type
   record["column_msg"] = column_msg
   record["column_entity"] = alert_entity
   record["column_entity_val"] = alert_entity_val

   res_formatted[#res_formatted + 1] = record
	  
end -- for

local result = {}
result["perPage"] = alert_options.perPage
result["currentPage"] = alert_options.currentPage
result["totalRows"] = num_alerts
result["data"] = res_formatted
result["sort"] = {{alert_options.sortColumn, alert_options.sortOrder}}

print(json.encode(result))

