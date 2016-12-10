--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "alert_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

status          = _GET["status"]

engaged = false
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

local alert_options = UrlToalertsQueryParameters(_GET)
--~ tprint(alert_options)

local num_alerts = tonumber(_GET["totalRows"])
if num_alerts == nil then
   num_alerts = getNumAlerts(status, alert_options)
end

local alerts = getAlerts(status, alert_options)

print ("{ \"currentPage\" : " .. alert_options.current_page .. ",\n \"data\" : [\n")
total = 0

if alerts == nil then alerts = {} end

for _key,_value in ipairs(alerts) do
   if(total > 0) then print(",\n") end

   alert_id        = _value["rowid"]
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
--   tprint(alert_entity)
   --   tprint(alert_entity_val)
   local tdiff = os.time()-_value["alert_tstamp"]

   if(tdiff < 3600) then
      column_date  = secondsToTime(tdiff).." ago"
   else
      column_date = os.date("%c", _value["alert_tstamp"])
   end

   column_duration = "-"
   if engaged == true then
      column_duration = secondsToTime(os.time() - tonumber(_value["alert_tstamp"]))
   elseif tonumber(_value["alert_tstamp_end"]) ~= nil then
      column_duration = secondsToTime(tonumber(_value["alert_tstamp_end"]) - tonumber(_value["alert_tstamp"]))
   end

   column_severity = alertSeverityLabel(tonumber(_value["alert_severity"]))
   column_type     = alertTypeLabel(tonumber(_value["alert_type"]))
   column_msg      = _value["alert_json"]

   column_id = "<form class=form-inline style='display:inline; margin-bottom: 0px;' method=GET>"

   for k, v in pairs(_GET) do
      column_id = column_id.."<input type=hidden name='"..k.."' value='"..v.."'>"
   end

   column_id = column_id.."<input type=hidden name=id_to_delete value="..alert_id.."><button class='btn btn-default btn-xs' type='submit'><input id=csrf name=csrf type=hidden value='"..ntop.getRandomCSRFValue().."' /><i type='submit' class='fa fa-trash-o'></i></button></form>"

   if ntop.isEnterprise() and (status == "historical-flows" or status == "historical") then
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
	    url = url..'&period_begin='..(tonumber(_value["alert_tstamp"]) - 1800)
	    url = url..'&period_end='..(tonumber(_value["alert_tstamp"]) + 1800)
	 end
	 return "&nbsp;<a class='btn btn-default btn-xs' href='"..url.."' title='"..i18n("flow_alerts_explorer.label").."'><i class='fa fa-history'></i><sup><i class='fa fa-exclamation-triangle' aria-hidden='true' style='position:absolute; margin-left:-19px; margin-top:4px;'></i></sup></a>&nbsp;"
      end
      column_id = column_id.." "..explore()

   end
   
   print('{ "column_key" : "'..column_id..'", "column_date" : "'..column_date..'", "column_duration" : "'..column_duration..'", "column_severity" : "'..column_severity..'", "column_type" : "'..column_type..'", "column_msg" : "'..column_msg..'", "column_entity":"'..alert_entity..'", "column_entity_val":"'..alert_entity_val..'" }')

   total = total + 1
end -- for

print ("\n], \"perPage\" : " .. alert_options.per_page .. ",\n")

print ("\"sort\" : [ [ \""..alert_options.sort_column .."\", \""..alert_options.sort_order.."\" ] ],\n")
print ("\"totalRows\" : " ..num_alerts .. " \n}")

