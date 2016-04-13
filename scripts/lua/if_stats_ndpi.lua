--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"

if_name = _GET["if_name"]
ifid = _GET["id"]

if ifid ~= nil and ifid ~= "" then
   if_name = getInterfaceName(ifid)
elseif if_name ~= nil and if_name ~= "" then
   ifid = tostring(interface.name2id(if_name))
else
   if_name = ifname
   ifid = interface.name2id(ifname)
end

interface.select(if_name)

ifstats = aggregateInterfaceStats(aggregateInterfaceStats(interface.getStats()))

format = _GET["format"]
if(format == "json") then
   sendHTTPHeader('application/json')
   json_format = true
else
   sendHTTPHeader('text/html; charset=iso-8859-1')
   json_format = false
end

total = ifstats["bytes"]

vals = {}

for k in pairs(ifstats["ndpi"]) do
 vals[k] = k
end

table.sort(vals)

if(json_format) then print('[\n') end

num = 0
for _k in pairsByKeys(vals, rev) do
  k = vals[_k]

  if(not(json_format)) then
     print('<tr id="t_protocol_'..k..'">')
     print('<th style="width: 33%;">')
  else
     if(num > 0) then
	print(',\n')
     end
  end

  fname = getRRDName(ifstats.id, nil, k..".rrd")
  if(ntop.exists(fname)) then
     if(not(json_format)) then
	print("<A HREF=\""..ntop.getHttpPrefix().."/lua/if_stats.lua?id=" .. ifid .. "&page=historical&rrd_file=".. k ..".rrd\">".. k .." "..formatBreed(ifstats["ndpi"][k]["breed"]).."</A>")
     else
	print('{ "proto": "'..k..'", "breed": "'..ifstats["ndpi"][k]["breed"]..'", ')
     end
  else
     if(not(json_format)) then
	print(k.." "..formatBreed(ifstats["ndpi"][k]["breed"]))
     else
	print('{ "proto": "'..k..'", ')
     end
  end

  t = ifstats["ndpi"][k]["bytes.sent"]+ifstats["ndpi"][k]["bytes.rcvd"]

  if(not(json_format)) then
     print(" <A HREF="..ntop.getHttpPrefix().."/lua/flows_stats.lua?application="..k.."><i class=\"fa fa-search-plus\"></i></A></th>")
     print("<td class=\"text-right\" style=\"width: 20%;\">" .. bytesToSize(t).. "</td>")
     print("<td ><span style=\"width: 60%; float: left;\">")
     percentageBar(total, t, "") -- k
     -- print("</td>\n")
     print("</span><span style=\"width: 40%; margin-left: 15px;\" >" ..round((t * 100)/total, 2).. " %</span></td></tr>\n")
  else
     print('"bytes": '..t..' }')
  end

  num = num + 1
end

if(json_format) then print('\n]\n') end
