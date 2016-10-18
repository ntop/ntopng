--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

currentPage = _GET["currentPage"]
perPage     = _GET["perPage"]
status      = _GET["alert_status"]
alertsImpl  = _GET["alerts_impl"]

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

engaged = false
if status == "engaged" then
   engaged = true
end

initial_idx = (currentPage-1)*perPage

interface.select(ifname)

local alerts
local num_alerts

if _GET["entity"] == "host" then
   alerts = interface.getAlerts(initial_idx, perPage, engaged, "host", _GET["entity_val"])
   num_alerts = interface.getNumAlerts(engaged, "host", _GET["entity_val"])
else
   alerts = interface.getAlerts(initial_idx, perPage, engaged)
   num_alerts = interface.getNumAlerts(engaged)
end

-- tprint(interface.getAlerts(initial_idx, perPage, engaged, "host", "192.168.1.29@0"))
-- tprint(interface.getNumAlerts(engaged, "host", "192.168.1.29@0"))

print ("{ \"currentPage\" : " .. currentPage .. ",\n \"data\" : [\n")
total = 0

if alerts == nil then alerts = {} end

for _key,_value in ipairs(alerts) do
   if(total > 0) then print(",\n") end

   alert_id        = _value["rowid"]
   alert_entity    = alertEntityLabel(_value["alert_entity"])
   alert_entity_val= _value["alert_entity_val"]
   column_date     = os.date("%c", _value["alert_tstamp"])
   if tonumber(_value["alert_tstamp_end"]) ~= nil then
      local duration = secondsToTime(tonumber(_value["alert_tstamp_end"]) - tonumber(_value["alert_tstamp"]))
      column_date = duration.." ending on "..os.date("%c", _value["alert_tstamp_end"])
   end
   column_severity = alertSeverityLabel(tonumber(_value["alert_severity"]))
   column_type     = alertTypeLabel(tonumber(_value["alert_type"]))
   column_msg      = _value["alert_json"]

   column_id = "<form class=form-inline style='margin-bottom: 0px;' method=get>"
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
   column_id = column_id.."<input type=hidden name=id_to_delete value="..alert_id.."><input type=hidden name=currentPage value=".. currentPage .."><input type=hidden name=perPage value=".. perPage .."><input type=hidden name=engaged value="..tostring(engaged).."><input type=hidden name=alerts_impl value="..tostring(alertsImpl).."><button class='btn btn-default btn-xs' type='submit'><input id=csrf name=csrf type=hidden value='"..ntop.getRandomCSRFValue().."' /><i type='submit' class='fa fa-trash-o'></i></button></form>"

   print('{ "column_key" : "'..column_id..'", "column_date" : "'..column_date..'", "column_severity" : "'..column_severity..'", "column_type" : "'..column_type..'", "column_msg" : "'..column_msg..'", "column_entity":"'..alert_entity..'", "column_entity_val":"'..alert_entity_val..'" }')

   total = total + 1
end -- for

print ("\n], \"perPage\" : " .. perPage .. ",\n")

print ("\"sort\" : [ [ \"\", \"\" ] ],\n")
print ("\"totalRows\" : " ..num_alerts .. " \n}")

