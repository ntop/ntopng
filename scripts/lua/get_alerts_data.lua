--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

currentPage = _GET["currentPage"]
perPage     = _GET["perPage"]

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

initial_idx = (currentPage-1)*perPage

interface.select(ifname)
alerts = interface.getQueuedAlerts(initial_idx, perPage)

print ("{ \"currentPage\" : " .. currentPage .. ",\n \"data\" : [\n")
total = 0

if alerts == nil then alerts = {} end
for _key,_value in pairs(alerts) do
   if(total > 0) then print(",\n") end
   values = split(string.gsub(_value, "\n", ""), "|")

   column_id = "<form class=form-inline style='margin-bottom: 0px;' method=get action='"..ntop.getHttpPrefix().."/lua/show_alerts.lua'><input type=hidden name=id_to_delete value="..(initial_idx+tonumber(_key)).."><input type=hidden name=currentPage value=".. currentPage .."><input type=hidden name=perPage value=".. perPage .."><button class='btn btn-default btn-xs' type='submit'><input id=csrf name=csrf type=hidden value='"..ntop.getRandomCSRFValue().."' /><i type='submit' class='fa fa-trash-o'></i></button></form>"
   column_date = os.date("%c", values[1])
   column_severity = alertSeverityLabel(tonumber(values[2]))
   column_type = alertTypeLabel(tonumber(values[4]))
   column_msg = values[5]

   print('{ "column_key" : "'..column_id..'", "column_date" : "'..column_date..'", "column_severity" : "'..column_severity..'", "column_type" : "'..column_type..'", "column_msg" : "'..column_msg..'" }')

   total = total + 1
end -- for

print ("\n], \"perPage\" : " .. perPage .. ",\n")

print ("\"sort\" : [ [ \"\", \"\" ] ],\n")
print ("\"totalRows\" : " .. interface.getNumQueuedAlerts() .. " \n}")
