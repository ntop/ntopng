--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local graph_utils = require "graph_utils"
local categories_utils = require "categories_utils"
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
   print("<div class=\"alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> "..i18n("ndpi_page.unable_to_find_host",{host_ip=host_ip}).."</div>")
   return
end

local total = 0
for k, v in pairs(host["ndpi_categories"]) do
   total = total + v["bytes"]
end

print("<tr><td colspan=2>Total</td><td class=\"text-end\">".. secondsToTime(host["total_activity_time"]) .."</td><td colspan=2 class=\"text-end\">" ..  bytesToSize(total).. "</td></tr>\n")

for k, v in pairsByKeys(host["ndpi_categories"], desc) do
   print("<tr><td>")
   local label = getCategoryLabel(k)

   if(areHostCategoriesTimeseriesEnabled(ifid, host)) then
      local details_href = hostinfo2detailshref(host, {page = "historical", ts_schema = "host:ndpi_categories", category = k}, label)
      print(details_href)
   else
      print(k)
   end

   local t = v["bytes"]

   print("</td>")

   print("<td>")
   print(categories_utils.get_category_protocols_list(v.category))
   print("</td>")

   print("<td class=\"text-end\">" .. secondsToTime(v["duration"]) .. "</td>")

   print("<td class=\"text-end\">" .. bytesToSize(t).. "</td><td class=\"text-end\">" .. round((t * 100)/total, 2).. " %</td></tr>\n")

end
