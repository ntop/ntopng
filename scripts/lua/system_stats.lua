--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
active_page = "system_stats"

require "lua_utils"
local page_utils = require("page_utils")
local ts_utils = require("ts_utils")
require("graph_utils")
require("alert_utils")

sendHTTPContentTypeHeader('text/html')

page_utils.print_header()

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local page = _GET["page"] or "historical"
local url = ntop.getHttpPrefix() .. "/lua/system_stats.lua?ifid=" .. getInterfaceId(ifname)

print [[
  <nav class="navbar navbar-default" role="navigation">
  <div class="navbar-collapse collapse">
    <ul class="nav navbar-nav">
]]

print("<li><a href=\"#\">" .. i18n("system") .. "</a></li>\n")

if(ts_utils.exists("process:memory", {})) then
   if(page == "historical") then
      print("<li class=\"active\"><a href=\""..url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
   else
      print("<li><a href=\""..url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
   end
end

if(isAdministrator() and areAlertsEnabled()) then
   if(page == "alerts") then
      print("\n<li class=\"active\"><a href=\"#\">")
   elseif not is_pcap_dump then
      print("\n<li><a href=\""..url.."&page=alerts\">")
   end

   if not is_pcap_dump then
      print("<i class=\"fa fa-warning fa-lg\"></i></a>")
      print("</li>")
   end
end

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>

   ]]

-- #######################################################

if(page == "historical") then
   local schema = _GET["ts_schema"] or "process:memory"
   local selected_epoch = _GET["epoch"] or ""
   local tags = {}
   url = url.."&page=historical"

   drawGraphs(getSystemInterfaceId(), schema, tags, _GET["zoom"], url, selected_epoch, {
      timeseries = {
         {schema="process:memory",             label=i18n("graphs.process_memory")},
      }
   })
elseif(page == "alerts") then
   local old_ifname = ifname
   interface.select(getSystemInterfaceId())

   _GET["ifid"] = getSystemInterfaceId()

   drawAlerts({hide_filters = true})

   interface.select(old_ifname)
end

-- #######################################################

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
