--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"
local ts_utils = require("ts_utils")

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

  if(not(json_format)) then
     print('<tr id="t_protocol_'..k..'">')
     print('<th style="width: 33%;">')
  else
     if(num > 0) then
	print(',\n')
     end
  end

  if(ts_utils.exists("iface:ndpi_categories", {ifid=ifid, protocol=k})) then
     if(not(json_format)) then
	print("<A HREF=\""..ntop.getHttpPrefix().."/lua/if_stats.lua?ifid=" .. ifid .. "&page=historical&ts_schema=iface:ndpi_categories&category=".. k .."\">".. k .." </A>")
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
     print("</th><td class=\"text-right\" style=\"width: 20%;\">" ..bytesToSize(t).. "</td>")
     print("<td ><span style=\"width: 60%; float: left;\">")
     percentageBar(total, t, "") -- k
     -- print("</td>\n")
     print("</span><span style=\"width: 40%; margin-left: 15px;\" >" ..round((t * 100)/total, 1).. " %</span></td></tr>\n")
  else
     print('"bytes": '..tostring(t)..' }')
  end

  num = num + 1
end

if(json_format) then print('\n]\n') end
