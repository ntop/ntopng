--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local graph_utils = require "graph_utils"
local categories_utils = require "categories_utils"

local ifid = _GET["ifid"]

if ifid ~= nil and ifid ~= "" then
   if_name = getInterfaceName(ifid)
else
   if_name = ifname
   ifid = interface.name2id(ifname)
end

interface.select(if_name)

local ifstats = interface.getStats()

local format = _GET["format"]
if(format == "json") then
   sendHTTPHeader('application/json')
   json_format = true
else
   sendHTTPContentTypeHeader('text/html')
   json_format = false
end

local total = ifstats.stats.bytes

if(json_format) then print('[\n') end

local num = 0
for k, v in pairsByKeys(ifstats["ndpi_categories"], asc) do
  local label = getCategoryLabel(k)

  if(not(json_format)) then
     print('<tr id="t_protocol_'..k..'">')
     print('<th style="width: 20%;">')
  else
     if(num > 0) then
	print(',\n')
     end
  end

  if(areInterfaceCategoriesTimeseriesEnabled(ifid)) then
     if(not(json_format)) then
	print("<A HREF=\""..ntop.getHttpPrefix().."/lua/if_stats.lua?ifid=" .. ifid .. "&page=historical&ts_schema=iface:ndpi_categories&category=".. k .."\">".. label .." </A>")
     else
	print('{ "proto": "'..k..'", ')
     end
  else
     if(not(json_format)) then
	print(k)
     else
	print('{ "proto": "'..k..'", ')
     end
  end

  local t = v["bytes"]

  if(not(json_format)) then
     print("</th>")
     print('<td  style="width: 50%;">')
     print(categories_utils.get_category_protocols_list(v.category))
     print("</td>")
     print("<td class=\"text-end\" style=\"width: 10%;\">" ..bytesToSize(t).. "</td>")
     print("<td ><span style=\"width: 60%; float: left;\">")
     graph_utils.percentageBar(total, t, "") -- k
     -- print("</td>\n")
     print("</span><span style=\"width: 40%; margin-left: 15px;\" >" ..round((t * 100)/total, 1).. " %</span></td></tr>\n")
  else
     print('"bytes": '..tostring(t)..' }')
  end

  num = num + 1
end

if(json_format) then print('\n]\n') end
