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

local probe = system_scripts.getSystemProbe("influxdb")
local page = _GET["page"] or "overview"
local url = system_scripts.getPageScriptPath(probe) .. "?ifid=" .. getInterfaceId(ifname)
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
   local fa_external =  "<i class='fa fa-external-link'></i>"
   local tags = {ifid=getSystemInterfaceId()}
    print("<table class=\"table table-bordered table-striped\">\n")

    print("<tr><td nowrap width='30%'><b>".. i18n("system_stats.health") .."</b><br><small>"..i18n("system_stats.short_desc_influxdb_health").."</small></td><td><img class=\"influxdb-info-load\" border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber><span id=\"influxdb-health\"></span></td></tr>\n")

    local storage_chart_available = ts_utils.exists("influxdb:storage_size", tags)
    print("<tr><td nowrap width='30%'><b>".. i18n("traffic_recording.storage_utilization") .."</b> "..ternary(storage_chart_available, "<A HREF='"..url.."&page=historical&ts_schema=influxdb:storage_size'><i class='fa fa-area-chart fa-sm'></i></A>", "").."<br><small>"..i18n("system_stats.short_desc_influxdb_storage_utilization").."</small></td><td><img class=\"influxdb-info-load\" border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber><span id=\"influxdb-info-text\"></span></td></tr>\n")

    -- No need to determine whether the chart exists for this as memory is always fetched straigth from influxdb
    print("<tr><td nowrap><b>".. i18n("about.ram_memory") .."</b> <A HREF='"..url.."&page=historical&ts_schema=influxdb:memory_size'><i class='fa fa-area-chart fa-sm'></i></A>".."<br><small>"..i18n("system_stats.short_desc_influxdb_ram_memory").."</small></td><td><img class=\"influxdb-info-load\" border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber><span id=\"influxdb-info-memory\"></span></td></tr>\n")

    if(probe ~= nil) then
       local stats = probe.getExportStats()

       local exports_chart_available = ts_utils.exists("influxdb:exports", tags)
       print("<tr><td nowrap><b>".. i18n("system_stats.exports") .."</b> "..ternary(exports_chart_available, "<A HREF='"..url.."&page=historical&ts_schema=influxdb:exports'><i class='fa fa-area-chart fa-sm'></i></A>", "").."<br><small>"..i18n("system_stats.short_desc_influxdb_exports").."</small></td><td><span id=\"influxdb-exports\">".. formatValue(stats.exports) .."</span></td></tr>\n")

       local exported_points_chart_available = ts_utils.exists("influxdb:exported_points", tags)
       print("<tr><td nowrap><b>".. i18n("system_stats.exported_points") .."</b> "..ternary(exported_points_chart_available, "<A HREF='"..url.."&page=historical&ts_schema=influxdb:exported_points'><i class='fa fa-area-chart fa-sm'></i></A>", "").."<br><small>"..i18n("system_stats.short_desc_influxdb_exported_points").."</small></td><td><span id=\"influxdb-exported-points\">".. formatValue(stats.points_exported) .."</span></td></tr>\n")

       local dropped_points_chart_available = ts_utils.exists("influxdb:dropped_points", tags)
       print("<tr><td nowrap><b>".. i18n("system_stats.dropped_points") .."</b> "..ternary(dropped_points_chart_available, "<A HREF='"..url.."&page=historical&ts_schema=influxdb:dropped_points'><i class='fa fa-area-chart fa-sm'></i></A>", "").."<br><small>"..i18n("system_stats.short_desc_influxdb_dropped_points").."</small></td><td><span id=\"influxdb-dropped-points\">".. formatValue(stats.points_dropped) .."</span></td></tr>\n")
    end

    print("<tr><td nowrap><b>".. i18n("system_stats.series_cardinality") .."</b><br><small>"..i18n("system_stats.short_desc_influxdb_cardinality").."</small></td><td><img class=\"influxdb-info-load\" border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber><span id=\"influxdb-info-series\"></span><i id=\"high-cardinality-warn\" class=\"fa fa-warning fa-lg\" title=\"".. i18n("system_stats.high_series_cardinality") .."\" style=\"color: orange; display:none\"></td></i></tr>\n")
    print[[<script>

 var last_db_bytes, last_memory, last_num_series;
 var last_exported_points, last_dropped_points;
 var last_exports;
 var health_descr = {
]]
    print('"green" : {"status" : "<span class=\'label label-success\'>'..i18n("system_stats.influxdb_health_green")..'</span>", "descr" : "<small>'..i18n("system_stats.influxdb_health_green_descr")..'</small>"},')
    print('"yellow" : {"status" : "<span class=\'label label-warning\'>'..i18n("system_stats.influxdb_health_yellow")..'</span>", "descr" : "<small>'..i18n("system_stats.influxdb_health_yellow_descr")..'</small>"},')
    print('"red" : {"status" : "<span class=\'label label-danger\'>'..i18n("system_stats.influxdb_health_red")..'</span>", "descr" : "<small>'..i18n("system_stats.influxdb_health_red_descr")..'</small>"},')
       print[[
 };

 function refreshInfluxStats() {
  $.get("]] print(ntop.getHttpPrefix()) print[[/lua/get_influxdb_info.lua", function(info) {
     $(".influxdb-info-load").hide();

     if(typeof info.health !== "undefined" && health_descr[info.health]) {
       $("#influxdb-health").html(health_descr[info.health]["status"] + "<br>" + health_descr[info.health]["descr"]);
     }
     if(typeof info.db_bytes !== "undefined") {
       $("#influxdb-info-text").html(bytesToVolume(info.db_bytes) + " ");
       if(typeof last_db_bytes !== "undefined")
         $("#influxdb-info-text").append(drawTrend(info.db_bytes, last_db_bytes));
       last_db_bytes = info.db_bytes;
     }
     if(typeof info.memory !== "undefined") {
       $("#influxdb-info-memory").html(bytesToVolume(info.memory) + " ");
       if(typeof last_memory !== "undefined")
         $("#influxdb-info-memory").append(drawTrend(info.memory, last_memory));
       last_memory = info.memory;
     }
     if(typeof info.num_series !== "undefined") {
       $("#influxdb-info-series").html(addCommas(info.num_series) + " ");
       if(typeof last_num_series !== "undefined")
         $("#influxdb-info-series").append(drawTrend(info.num_series, last_num_series));
       last_num_series = info.num_series;
     }
     if(typeof info.points_exported !== "undefined") {
       $("#influxdb-exported-points").html(addCommas(info.points_exported) + " ");
       if(typeof last_exported_points !== "undefined")
         $("#influxdb-exported-points").append(drawTrend(info.points_exported, last_exported_points));
       last_exported_points = info.points_exported;
     }
     if(typeof info.points_dropped !== "undefined") {
       $("#influxdb-dropped-points").html(addCommas(info.points_dropped) + " ");
       if(typeof last_dropped_points !== "undefined")
         $("#influxdb-dropped-points").append(drawTrend(info.points_dropped, last_dropped_points, " style=\"color: #B94A48;\""));
       last_dropped_points = info.points_dropped;
     }
     if(typeof info.exports !== "undefined") {
       $("#influxdb-exports").html(addCommas(info.exports) + " ");
       if(typeof last_exports !== "undefined")
         $("#influxdb-exports").append(drawTrend(info.exports, last_exports));
       last_exports = info.exports;
     }

     if(info.num_series >= 950000)
       $("#high-cardinality-warn").show();
  }).fail(function() {
     $(".influxdb-info-load").hide();
  });
 }

setInterval(refreshInfluxStats, 5000);
refreshInfluxStats();
 </script>
 ]]
       print("</table>\n")
       print("<b>"..i18n("notes").."</b>")
       print("<ul>")
       print("<li>"..i18n("system_stats.influxdb_note_docs", {url = "https://www.ntop.org/guides/ntopng/basic_concepts/timeseries.html#influxdb-driver"}).."</li>")
       print("</ul>")
       
elseif(page == "historical") then
   local schema = _GET["ts_schema"] or "influxdb:storage_size"
   local selected_epoch = _GET["epoch"] or ""
   local tags = {ifid = getSystemInterfaceId()}
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
