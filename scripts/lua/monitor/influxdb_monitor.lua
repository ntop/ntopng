--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

require "lua_utils"
local page_utils = require("page_utils")
local ts_utils = require("ts_utils")
local script_manager = require("script_manager")
local graph_utils = require("graph_utils")
local influxdb_export_api = require "influxdb_export_api"

sendHTTPContentTypeHeader('text/html')

local charts_available = script_manager.systemTimeseriesEnabled()
local page = _GET["page"] or "overview"
local url = script_manager.getMonitorUrl("influxdb_monitor.lua") .. "?ifid=" .. interface.getId()

page_utils.set_active_menu_entry(page_utils.menu_entries.influxdb_status)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_navbar("InfluxDB", url,
			{
			   {
			      active = page == "overview" or not page,
			      page_name = "overview",
			      label = "<i class=\"fas fa-home fa-lg\"></i>",
			   },
			   {
			      hidden = not charts_available,
			      active = page == "historical",
			      page_name = "historical",
			      label = "<i class='fas fa-lg fa-chart-area'></i>",
			   },
			}
)

-- #######################################################

if(page == "overview") then
   local fa_external =  "<i class='fas fa-external-link-alt'></i>"
   local tags = {ifid=getSystemInterfaceId()}
    print("<table class=\"table table-bordered table-striped\">\n")

    print("<tr><td nowrap width='30%'><b>".. i18n("system_stats.health") .."</b><br><small>"..i18n("system_stats.short_desc_influxdb_health").."</small></td><td></td><td><span id='throbber' class='spinner-border spinner-border-sm text-primary influxdb-info-load' role='status'><span class='sr-only'>Loading...</span></span> <span id=\"influxdb-health\"></span></td></tr>\n")

    print("<tr><td nowrap width='30%'><b>".. i18n("traffic_recording.storage_utilization") .."</b><br><small>"..i18n("system_stats.short_desc_influxdb_storage_utilization").."</small></td>")
    print("<td class='text-center' width=5%>")
    print(ternary(charts_available, "<A HREF='"..url.."&page=historical&ts_schema=influxdb:storage_size'><i class='fas fa-chart-area fa-lg'></i></A>", ""))
    print("</td><td><span id='throbber' class='spinner-border influxdb-info-load spinner-border-sm text-primary' role='status'><span class='sr-only'>Loading...</span></span> <span id=\"influxdb-info-text\"></span></td></tr>\n")

    print("<tr><td nowrap><b>".. i18n("about.ram_memory") .."</b><br><small>"..i18n("system_stats.short_desc_influxdb_ram_memory").."</small></td>")
    print("<td class='text-center' width=5%>")
    print(ternary(charts_available, "<A HREF='"..url.."&page=historical&ts_schema=influxdb:memory_size'><i class='fas fa-chart-area fa-lg'></i></A>", ""))
    print("</td><td><span id='throbber' class='spinner-border influxdb-info-load spinner-border-sm text-primary' role='status'><span class='sr-only'>Loading...</span></span> <span id=\"influxdb-info-memory\"></span></td></tr>\n")

    if(influxdb_export_api.isInfluxdbChecksEnabled() == true) then
       local stats = influxdb_export_api.getExportStats()

       print("<tr><td nowrap><b>".. i18n("system_stats.exports") .."</b><br><small>"..i18n("system_stats.short_desc_influxdb_exports").."</small></td>")
       print("<td class='text-center' width=5%>")
       print(ternary(charts_available, "<A HREF='"..url.."&page=historical&ts_schema=influxdb:exports'><i class='fas fa-chart-area fa-lg'></i></A>", ""))
       print("<td><span id=\"influxdb-exports\">".. formatValue(stats.exports) .."</span></td></tr>\n")

       print("<tr><td nowrap><b>".. i18n("system_stats.exported_points") .."</b><br><small>"..i18n("system_stats.short_desc_influxdb_exported_points").."</small></td>")
       print("<td class='text-center' width=5%>")
       print(ternary(charts_available, "<A HREF='"..url.."&page=historical&ts_schema=influxdb:exported_points'><i class='fas fa-chart-area fa-lg'></i></A>", ""))
       print("</td><td><span id=\"influxdb-exported-points\">".. formatValue(stats.points_exported) .."</span></td></tr>\n")
    end

    print("<tr><td nowrap><b>".. i18n("system_stats.series_cardinality") .."</b><br><small>"..i18n("system_stats.short_desc_influxdb_cardinality").."</small></td><td></td><td><span id='throbber' class='spinner-border influxdb-info-load spinner-border-sm text-primary' role='status'><span class='sr-only'>Loading...</span></span> <span id=\"influxdb-info-series\"></span><i id=\"high-cardinality-warn\" class=\"fas fa-exclamation-triangle fa-lg\" title=\"".. i18n("system_stats.high_series_cardinality") .."\" style=\"color: orange; display:none\"></td></i></tr>\n")
    print[[<script>

 var last_db_bytes, last_memory, last_num_series;
 var last_exported_points, last_dropped_points;
 var last_exports;
 var health_descr = {
]]
    print('"green" : {"status" : "<span class=\'badge bg-success\'>'..i18n("system_stats.influxdb_health_green")..'</span>", "descr" : "<small>'..i18n("system_stats.influxdb_health_green_descr")..'</small>"},')
    print('"yellow" : {"status" : "<span class=\'badge bg-warning\'>'..i18n("system_stats.influxdb_health_yellow")..'</span>", "descr" : "<small>'..i18n("system_stats.influxdb_health_yellow_descr")..'</small>"},')
    print('"red" : {"status" : "<span class=\'badge bg-danger\'>'..i18n("system_stats.influxdb_health_red")..'</span>", "descr" : "<small>'..i18n("system_stats.influxdb_health_red_descr")..'</small>"},')
       print[[
 };

 function refreshInfluxStats() {
  $.get("]] print(ntop.getHttpPrefix()) print[[/lua/get_influxdb_info.lua", function(info) {
    const rsp = info.rsp 
    $(".influxdb-info-load").hide();

     let influxdb_status = health_descr['green']["status"] + "<br>" + health_descr['green']["descr"]
     if(typeof rsp.health !== "undefined" && health_descr[rsp.health]) {
      influxdb_status = health_descr[rsp.health]["status"] + "<br>" + health_descr[rsp.health]["descr"]
     }

     $("#influxdb-health").html(influxdb_status);

     if(typeof rsp.db_bytes !== "undefined") {
       $("#influxdb-info-text").html(NtopUtils.bytesToVolume(rsp.db_bytes) + " ");
       if(typeof last_db_bytes !== "undefined")
         $("#influxdb-info-text").append(NtopUtils.drawTrend(rsp.db_bytes, last_db_bytes));
       last_db_bytes = rsp.db_bytes;
     }
     if(typeof rsp.memory !== "undefined") {
       $("#influxdb-info-memory").html(NtopUtils.bytesToVolume(rsp.memory) + " ");
       if(typeof last_memory !== "undefined")
         $("#influxdb-info-memory").append(NtopUtils.drawTrend(rsp.memory, last_memory));
       last_memory = rsp.memory;
     }
     if(typeof rsp.num_series !== "undefined") {
       $("#influxdb-info-series").html(NtopUtils.addCommas(rsp.num_series) + " ");
       if(typeof last_num_series !== "undefined")
         $("#influxdb-info-series").append(NtopUtils.drawTrend(rsp.num_series, last_num_series));
       last_num_series = rsp.num_series;
     }
     if(typeof rsp.points_exported !== "undefined") {
       $("#influxdb-exported-points").html(NtopUtils.addCommas(rsp.points_exported) + " ");
       if(typeof last_exported_points !== "undefined")
         $("#influxdb-exported-points").append(NtopUtils.drawTrend(rsp.points_exported, last_exported_points));
       last_exported_points = rsp.points_exported;
     }
     if(typeof rsp.points_dropped !== "undefined") {
       $("#influxdb-dropped-points").html(NtopUtils.addCommas(rsp.points_dropped) + " ");
       if(typeof last_dropped_points !== "undefined")
         $("#influxdb-dropped-points").append(NtopUtils.drawTrend(rsp.points_dropped, last_dropped_points, " style=\"color: #B94A48;\""));
       last_dropped_points = rsp.points_dropped;
     }
     if(typeof rsp.exports !== "undefined") {
       $("#influxdb-exports").html(NtopUtils.addCommas(rsp.exports) + " ");
       if(typeof last_exports !== "undefined")
         $("#influxdb-exports").append(NtopUtils.drawTrend(rsp.exports, last_exports));
       last_exports = rsp.exports;
     }

     if(rsp.num_series >= 950000)
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

elseif(page == "historical" and charts_available) then
   graph_utils.drawNewGraphs(nil, interface.getId())
end

-- #######################################################

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
