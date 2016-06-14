--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')


ifid = _GET["ifid"]

interface.select(ifid)
host_info = url2hostinfo(_GET)
host_ip = host_info["host"]
host_vlan = host_info["vlan"]
host = interface.getHostInfo(host_ip, host_vlan)
host_ndpi_rrd_creation = ntop.getCache("ntopng.prefs.host_ndpi_rrd_creation")

local now    = os.time()
local ago1h  = now - 3600
local protos = interface.getnDPIProtocols()

if(host == nil) then
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Unable to find "..host_ip.." (data expired ?)</div>")
   return
end

total = host["bytes.sent"]+host["bytes.rcvd"]

vals = {}
for k in pairs(host["ndpi"]) do
  vals[k] = k
  -- print(k)
end
table.sort(vals)

print("<tr><td>Total</td><td class=\"text-right\">" .. bytesToSize(host["bytes.sent"]) .. "</td><td class=\"text-right\">" .. bytesToSize(host["bytes.rcvd"]) .. "</td>")

print("<td>")
breakdownBar(host["bytes.sent"], "Sent", host["bytes.rcvd"], "Rcvd", 0, 100)
print("</td>\n")

print("<td colspan=2 class=\"text-right\">" ..  bytesToSize(total).. "</td></tr>\n")

for _k in pairsByKeys(vals , desc) do
  k = vals[_k]
  print("<tr><td>")
  fname = getRRDName(ifid, hostinfo2hostkey(host_info), k..".rrd")
  if(ntop.exists(fname)) then
    print("<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?ifname="..ifid.."&"..hostinfo2url(host_info) .. "&page=historical&rrd_file=".. k ..".rrd\">"..k.." "..formatBreed(host["ndpi"][k]["breed"]).."</A>")
  else
    print(k.." "..formatBreed(host["ndpi"][k]["breed"]))
  end
  t = host["ndpi"][k]["bytes.sent"]+host["ndpi"][k]["bytes.rcvd"]

  if((host["ndpi"][k]["bytes.sent"] == 0) and (host["ndpi"][k]["bytes.rcvd"] > 0)) then
     print(" <i class=\"fa fa-warning fa-lg\" style=\"color: orange;\"></i>")
  end

  if ntop.isPro() and ntop.getPrefs().is_dump_flows_to_mysql_enabled == true then
     local hist_url = ntop.getHttpPrefix().."/lua/pro/db_explorer.lua?search=true&ifId="..getInterfaceId(ifname)
     hist_url = hist_url.."&epoch_end="..tostring(now)
     hist_url = hist_url.."&"..hostinfo2url(host)
     hist_url = hist_url.."&protocol="..protos[k]
     print('&nbsp;')
     print('<a href="'..hist_url..'&epoch_begin='..tostring(ago1h)..'" title="Flows seen in the latest hour"><i class="fa fa-history"></i></a>')
  end

  print('</td>')
  print("<td class=\"text-right\">" .. bytesToSize(host["ndpi"][k]["bytes.sent"]) .. "</td><td class=\"text-right\">" .. bytesToSize(host["ndpi"][k]["bytes.rcvd"]) .. "</td>")

  print("<td>")
  breakdownBar(host["ndpi"][k]["bytes.sent"], "Sent", host["ndpi"][k]["bytes.rcvd"], "Rcvd", 0, 100)
  print("</td>\n")

  print("<td class=\"text-right\">" .. bytesToSize(t).. "</td><td class=\"text-right\">" .. round((t * 100)/total, 2).. " %</td></tr>\n")
end
if host_ndpi_rrd_creation ~= "1" then
print("<tr><td colspan=\"6\"> <small> <b>NOTE</b>:<ul>")
print("<li>Historical per-protocol traffic data can be enabled via ntopng <a href=\""..ntop.getHttpPrefix().."/lua/admin/prefs.lua\"<i class=\"fa fa-flask\"></i> Preferences</a>.")
print(" When enabled, RRDs with 5-minute samples will be created for each protocol detected and historical data will become accessible by clicking on each protocol. ")
print("<li>An icon like <i class=\"fa fa-warning fa-sm\" style=\"color: orange;\"></i> indicates a possible probing (or application server down) alert as the host has received traffic for a specific application protocol without sending back any data. You can use <A HREF=/lua/host_details.lua?ifname="..ifid.."&host=".._GET["host"].."&page=historical>historical reports</A> to drill-down this issue.")
print("</ul>")
end
print("</small> </p></td></tr>")
