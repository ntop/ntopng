--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

currentPage = _GET["currentPage"]
perPage     = _GET["perPage"]
sortColumn  = _GET["sortColumn"]
sortOrder   = _GET["sortOrder"]

status          = _GET["alert_status"]
alertsImpl      = _GET["alerts_impl"]
alert_severity  = _GET["severity"]
alert_type      = _GET["type"]

if alert_severity ~= nil and alert_severity ~= "" then
   alert_severity = alertSeverity(alert_severity)
end
if alert_type ~= nil and alert_type ~= "" then
   alert_type = alertType(alert_type)
end

if sortColumn == nil or sortColumn == "column_" or sortColumn == "" then
   sortColumn = getDefaultTableSort("alerts")
elseif sortColumn ~= "column_" and  sortColumn ~= "" then
   tablePreferences("sort_alerts",sortColumn)
else
   sortColumn = "column_date"
end

if sortOrder == nil then
   sortOrder = getDefaultTableSortOrder("alerts")
elseif sortColumn ~= "column_" and sortColumn ~= "" then
   tablePreferences("sort_order_alerts",sortOrder)
end

if(currentPage == nil) then
   currentPage = 1
else
   currentPage = tonumber(currentPage)
end

if(perPage == nil) then
   perPage = getDefaultTableSize()
else
   perPage = tonumber(perPage)
end

local a2z = false
if(sortOrder == "asc") then a2z = true else a2z = false end

to_skip = (currentPage-1) * perPage

local paginfo = {
   ["sortColumn"] = sortColumn, ["toSkip"] = to_skip, ["maxHits"] = perPage,
   ["a2zSortOrder"] = a2z,
   ["severityFilter"] = alert_severity,
   ["typeFilter"] = alert_type
}

engaged = false
if status == "engaged" then
   engaged = true
end


interface.select(ifname)

local alerts
local num_alerts

if _GET["entity"] == "host" then
   paginfo["entityFilter"] = alertEntity("host")
   paginfo["entityValueFilter"] = _GET["entity_val"]
   alerts = interface.getAlerts(paginfo, engaged)
   num_alerts = interface.getNumAlerts(engaged, "host", _GET["entity_val"])

elseif status == "historical-flows" then
   alerts = interface.getFlowAlerts(paginfo)
   num_alerts = interface.getNumFlowAlerts()

else --if status == "historical" then
   alerts = interface.getAlerts(paginfo, engaged)
   num_alerts = interface.getNumAlerts(engaged)

end

print ("{ \"currentPage\" : " .. currentPage .. ",\n \"data\" : [\n")
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
   column_date     = os.date("%c", _value["alert_tstamp"])

   column_duration = "-"
   if tonumber(_value["alert_tstamp_end"]) ~= nil then
      column_duration = secondsToTime(tonumber(_value["alert_tstamp_end"]) - tonumber(_value["alert_tstamp"]))
   end

   column_severity = alertSeverityLabel(tonumber(_value["alert_severity"]))
   column_type     = alertTypeLabel(tonumber(_value["alert_type"]))
   column_msg      = _value["alert_json"]

   column_id = "<form class=form-inline style='margin-bottom: 0px;' method=GET>"
   if _GET["ifname"] ~= nil and _GET["ifname"] ~= "" then
      column_id = column_id.."<input type=hidden name=ifname value=".._GET["ifname"]..">"
   end
   if _GET["host"] ~= nil and _GET["host"] ~= "" then
      column_id = column_id.."<input type=hidden name=host value=".._GET["host"]..">"
   end
   if _GET["vlan"] ~= nil and _GET["vlan"] ~= "" then
      column_id = column_id.."<input type=hidden name=vlan value=".._GET["vlan"]..">"
   end
   if _GET["page"] ~= nil and _GET["page"] ~= "" then
      column_id = column_id.."<input type=hidden name=page value=".._GET["page"]..">"
   end
   column_id = column_id.."<input type=hidden name=id_to_delete value="..alert_id.."><input type=hidden name=currentPage value=".. currentPage .."><input type=hidden name=perPage value=".. perPage .."><input type=hidden name=status value="..tostring(status).."><input type=hidden name=alerts_impl value="..tostring(alertsImpl).."><button class='btn btn-default btn-xs' type='submit'><input id=csrf name=csrf type=hidden value='"..ntop.getRandomCSRFValue().."' /><i type='submit' class='fa fa-trash-o'></i></button></form>"

   print('{ "column_key" : "'..column_id..'", "column_date" : "'..column_date..'", "column_duration" : "'..column_duration..'", "column_severity" : "'..column_severity..'", "column_type" : "'..column_type..'", "column_msg" : "'..column_msg..'", "column_entity":"'..alert_entity..'", "column_entity_val":"'..alert_entity_val..'" }')

   total = total + 1
end -- for

print ("\n], \"perPage\" : " .. perPage .. ",\n")

print ("\"sort\" : [ [ \""..sortColumn.."\", \""..sortOrder.."\" ] ],\n")
print ("\"totalRows\" : " ..num_alerts .. " \n}")

