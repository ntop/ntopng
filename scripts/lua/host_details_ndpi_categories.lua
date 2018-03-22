--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"
require "historical_utils"

sendHTTPContentTypeHeader('text/html')

local ifid = _GET["ifid"]

interface.select(ifid)
local host_info = url2hostinfo(_GET)
local host_ip = host_info["host"]
local host_vlan = host_info["vlan"]
local host = interface.getHostInfo(host_ip, host_vlan)

local now    = os.time()
local ago1h  = now - 3600
local protos = interface.getnDPIProtocols()

if(host == nil) then
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> "..i18n("ndpi_page.unable_to_find_host",{host_ip=host_ip}).."</div>")
   return
end

local total = 0
for k, v in pairs(host["ndpi_categories"]) do
   total = total + v["bytes"]
end

print("<tr><td>Total</td><td class=\"text-right\">".. secondsToTime(host["total_activity_time"]) .."</td><td colspan=2 class=\"text-right\">" ..  bytesToSize(total).. "</td></tr>\n")

for k, v in pairsByKeys(host["ndpi_categories"], desc) do
   print("<tr><td>")
   local fname = getRRDName(ifid, hostinfo2hostkey(host_info), k..".rrd")

   if(ntop.exists(fname)) then
      print("<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?ifid="..ifid.."&"..hostinfo2url(host_info) .. "&page=historical&rrd_file=".. k ..".rrd\">"..k.."</A>")
   else
      print(k)
   end

   local t = v["bytes"]

   print('</td>')

   print("<td class=\"text-right\">" .. secondsToTime(v["duration"]) .. "</td>")

   print("<td class=\"text-right\">" .. bytesToSize(t).. "</td><td class=\"text-right\">" .. round((t * 100)/total, 2).. " %</td></tr>\n")

end
