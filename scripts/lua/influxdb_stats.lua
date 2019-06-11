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
local system_scripts = require("system_scripts_utils")
require("graph_utils")
require("alert_utils")

if not isAllowedSystemInterface() or (ts_utils.getDriverName() ~= "influxdb") then
   return
end

sendHTTPContentTypeHeader('text/html')

page_utils.print_header()

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local page = _GET["page"] or "overview"
local url = ntop.getHttpPrefix() .. "/lua/influxdb_stats.lua?ifid=" .. getInterfaceId(ifname)
local info = ntop.getInfo()
system_schemas = system_scripts.getAdditionalTimeseries("influxdb")

print [[
  <nav class="navbar navbar-default" role="navigation">
  <div class="navbar-collapse collapse">
    <ul class="nav navbar-nav">
]]

print("<li><a href=\"#\">" .. "InfluxDB" .. "</a></li>\n")

if((page == "overview") or (page == nil)) then
   print("<li class=\"active\"><a href=\"#\"><i class=\"fa fa-home fa-lg\"></i></a></li>\n")
else
   print("<li><a href=\""..url.."&page=overview\"><i class=\"fa fa-home fa-lg\"></i></a></li>")
end

if(page == "historical") then
  print("<li class=\"active\"><a href=\""..url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
else
  print("<li><a href=\""..url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
end

if(isAdministrator() and system_scripts.hasAlerts({entity = alertEntity("influx_db")})) then
   if(page == "alerts") then
      print("\n<li class=\"active\"><a href=\"#\">")
   else
      print("\n<li><a href=\""..url.."&page=alerts\">")
   end

   print("<i class=\"fa fa-warning fa-lg\"></i></a>")
   print("</li>")
end

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>

   ]]

-- #######################################################

if(page == "overview") then
   local probe = system_scripts.getSystemProbe("influxdb")

    print("<table class=\"table table-bordered table-striped\">\n")

    print("<tr><th nowrap width='20%'>".. i18n("system_stats.influxdb_storage", {dbname = ts_utils.getQueryDriver().db}) .."</th><td><img class=\"influxdb-info-load\" border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber><span id=\"influxdb-info-text\"></span></td></tr>\n")
    print("<tr><th nowrap>".. i18n("memory") .."</th><td><img class=\"influxdb-info-load\" border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber><span id=\"influxdb-info-memory\"></span></td></tr>\n")

    if(probe ~= nil) then
       local stats = probe.getExportStats()
       print("<tr><th nowrap>".. i18n("system_stats.exported_points") .."</th><td>".. formatValue(stats.points_exported) .."</td></tr>\n")
       print("<tr><th nowrap>".. i18n("system_stats.dropped_points") .."</th><td>".. formatValue(stats.points_dropped) .."</td></tr>\n")
    end

    print("<tr><th nowrap>".. i18n("system_stats.series_cardinality") .." <a href=\"https://docs.influxdata.com/influxdb/v1.7/concepts/glossary/#series-cardinality\"><i class='fa fa-external-link '></i></a></th><td><img class=\"influxdb-info-load\" border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber><span id=\"influxdb-info-series\"></span></td></tr>\n")
    print[[<script>
 $(function() {
    $.get("]] print(ntop.getHttpPrefix()) print[[/lua/get_influxdb_info.lua", function(info) {
       $(".influxdb-info-load").hide();
       $("#influxdb-info-text").html(bytesToVolume(info.db_bytes) + " ");
       $("#influxdb-info-memory").html(bytesToVolume(info.memory) + " ");
       $("#influxdb-info-series").html(addCommas(info.num_series) + " ");
    }).fail(function() {
       $(".influxdb-info-load").hide();
    });
 });
 </script>
 ]]

   print("</table>\n")
elseif(page == "historical") then
   local schema = _GET["ts_schema"] or "influxdb:storage_size"
   local selected_epoch = _GET["epoch"] or ""
   local tags = {}
   url = url.."&page=historical"

   drawGraphs(getSystemInterfaceId(), schema, tags, _GET["zoom"], url, selected_epoch, {
      timeseries = system_schemas,
   })
elseif((page == "alerts") and isAdministrator()) then
   local old_ifname = ifname
   local influxdb = ts_utils.getQueryDriver()
   interface.select(getSystemInterfaceId())

   _GET["ifid"] = getSystemInterfaceId()
   _GET["entity"] = alertEntity("influx_db")

   drawAlerts({hide_filters = true})

   interface.select(old_ifname)
end

-- #######################################################

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
