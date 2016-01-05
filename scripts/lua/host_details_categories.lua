--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"

host_ip = _GET["hostip"]
ifid = _GET["ifid"]

sendHTTPHeader('text/html; charset=iso-8859-1')

interface.select(ifid)
host_info = hostkey2hostinfo(host_ip)
host_vlan = host_info["vlan"]
host = interface.getHostInfo(host_info["host"], host_vlan)
host_categories_rrd_creation = ntop.getCache("ntopng.prefs.host_categories_rrd_creation")

if(host == nil) then
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Unable to find "..host_ip.." (data expired ?)</div>")
   return
end

total = 0

vals = {}

if(host["categories"] ~= nil) then
for k,v in pairs(host["categories"]) do
  vals[k] = k
  total = total + v
  -- print(k)
end
table.sort(vals)
end


for _k,_label in pairsByKeys(vals , desc) do
  label = getCategoryLabel(_label)
  print("<tr><th>")
  fname = getRRDName(ifid, hostinfo2hostkey(host_info), "categories/"..label..".rrd")
  if ntop.exists(fname) and host_categories_rrd_creation ~= "0" then
    print("<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?ifname="..ifid.."&"..hostinfo2url(host_info) .. "&page=historical&rrd_file=categories/".. label ..".rrd\">"..label.."</A>")
  else
    print(label)
  end
  print("</th><td colspan=\"2\" class=\"text-right\">" .. bytesToSize(host["categories"][_label]) .. "</td>")
  print("<td class=\"text-right\">" .. round((host["categories"][_label] * 100)/total, 2).. " %</td></tr>")
end
  print("<tr><td colspan=\"4\"> <small> <b>NOTE</b>:<p>Percentages are related only to classified traffic.</p> </small> </td></tr>")
