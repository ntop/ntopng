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
local alert_consts = require("alert_consts")
local user_scripts = require("user_scripts")
local plugins_utils = require("plugins_utils")
require("graph_utils")
require("alert_utils")

local ts_creation = plugins_utils.timeseriesCreationEnabled()
local probe = user_scripts.loadModule(getSystemInterfaceId(), user_scripts.script_types.system, "system", "influxdb_monitor")

if not isAllowedSystemInterface() or (ts_utils.getDriverName() ~= "influxdb") then
   return
end

sendHTTPContentTypeHeader('text/html')

page_utils.print_header()

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local page = _GET["page"] or "overview"
local url = plugins_utils.getUrl("influxdb_stats.lua") .. "?ifid=" .. interface.getId()
local title = "InfluxDB"

page_utils.print_navbar(title, url,
			{
			   {
			      active = page == "overview" or not page,
			      page_name = "overview",
			      label = "<i class=\"fas fa-home fa-lg\"></i>",
			   },
			   {
			      hidden = not ts_creation,
			      active = page == "historical",
			      page_name = "historical",
			      label = "<i class='fas fa-lg fa-chart-area'></i>",
			   },
			   {
			      hidden = interface.isPcapDumpInterface() or not isAdministrator() or not areAlertsEnabled() or not plugins_utils.hasAlerts(getSystemInterfaceId(), {entity = alert_consts.alertEntity("influx_db")}),
			      active = page == "alerts",
			      page_name = "alerts",
			      label = "<i class=\"fas fa-exclamation-triangle fa-lg\"></i>",
			   },
			}
)

-- #######################################################

if(page == "overview") then
   local fa_external =  "<i class='fas fa-external-link-alt'></i>"
   local tags = {ifid=getSystemInterfaceId()}
    print("<table class=\"table table-bordered table-striped\">\n")

    print("<tr><td nowrap width='30%'><b>".. i18n("system_stats.health") .."</b><br><small>"..i18n("system_stats.short_desc_influxdb_health").."</small></td><td></td><td><img class=\"influxdb-info-load\" border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber><span id=\"influxdb-health\"></span></td></tr>\n")

    local storage_chart_available = ts_creation and ts_utils.exists("influxdb:storage_size", tags)
    print("<tr><td nowrap width='30%'><b>".. i18n("traffic_recording.storage_utilization") .."</b><br><small>"..i18n("system_stats.short_desc_influxdb_storage_utilization").."</small></td>")
    print("<td class='text-center' width=5%>")
    print(ternary(storage_chart_available, "<A HREF='"..url.."&page=historical&ts_schema=influxdb:storage_size'><i class='fas fa-chart-area fa-lg'></i></A>", ""))
    print("</td><td><img class=\"influxdb-info-load\" border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber><span id=\"influxdb-info-text\"></span></td></tr>\n")

    local ram_chart_available = ts_creation and ts_utils.exists("influxdb:memory_size", tags)
    print("<tr><td nowrap><b>".. i18n("about.ram_memory") .."</b><br><small>"..i18n("system_stats.short_desc_influxdb_ram_memory").."</small></td>")
    print("<td class='text-center' width=5%>")
    print(ternary(ram_chart_available, "<A HREF='"..url.."&page=historical&ts_schema=influxdb:memory_size'><i class='fas fa-chart-area fa-lg'></i></A>", ""))
    print("</td><td><img class=\"influxdb-info-load\" border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber><span id=\"influxdb-info-memory\"></span></td></tr>\n")

    if(probe ~= nil) then
       local stats = probe.getExportStats()

       local exports_chart_available = ts_creation and ts_utils.exists("influxdb:exports", tags)
       print("<tr><td nowrap><b>".. i18n("system_stats.exports") .."</b><br><small>"..i18n("system_stats.short_desc_influxdb_exports").."</small></td>")
       print("<td class='text-center' width=5%>")
       print(ternary(exports_chart_available, "<A HREF='"..url.."&page=historical&ts_schema=influxdb:exports'><i class='fas fa-chart-area fa-lg'></i></A>", ""))
       print("<td><span id=\"influxdb-exports\">".. formatValue(stats.exports) .."</span></td></tr>\n")

       local exported_points_chart_available = ts_creation and ts_utils.exists("influxdb:exported_points", tags)
       print("<tr><td nowrap><b>".. i18n("system_stats.exported_points") .."</b><br><small>"..i18n("system_stats.short_desc_influxdb_exported_points").."</small></td>")
       print("<td class='text-center' width=5%>")
       print(ternary(exported_points_chart_available, "<A HREF='"..url.."&page=historical&ts_schema=influxdb:exported_points'><i class='fas fa-chart-area fa-lg'></i></A>", ""))
       print("</td><td><span id=\"influxdb-exported-points\">".. formatValue(stats.points_exported) .."</span></td></tr>\n")

       local dropped_points_chart_available = ts_creation and ts_utils.exists("influxdb:dropped_points", tags)
       print("<tr><td nowrap><b>".. i18n("system_stats.dropped_points") .."</b><br><small>"..i18n("system_stats.short_desc_influxdb_dropped_points").."</small></td>")
       print("<td class='text-center' width=5%>")
       print(ternary(dropped_points_chart_available, "<A HREF='"..url.."&page=historical&ts_schema=influxdb:dropped_points'><i class='fas fa-chart-area fa-lg'></i></A>", ""))
       print("</td><td><span id=\"influxdb-dropped-points\">".. formatValue(stats.points_dropped) .."</span></td></tr>\n")
    end

    print("<tr><td nowrap><b>".. i18n("system_stats.series_cardinality") .."</b><br><small>"..i18n("system_stats.short_desc_influxdb_cardinality").."</small></td><td></td><td><img class=\"influxdb-info-load\" border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber><span id=\"influxdb-info-series\"></span><i id=\"high-cardinality-warn\" class=\"fas fa-exclamation-triangle fa-lg\" title=\"".. i18n("system_stats.high_series_cardinality") .."\" style=\"color: orange; display:none\"></td></i></tr>\n")
    print[[<script>

 var last_db_bytes, last_memory, last_num_series;
 var last_exported_points, last_dropped_points;
 var last_exports;
 var health_descr = {
]]
    print('"green" : {"status" : "<span class=\'badge badge-success\'>'..i18n("system_stats.influxdb_health_green")..'</span>", "descr" : "<small>'..i18n("system_stats.influxdb_health_green_descr")..'</small>"},')
    print('"yellow" : {"status" : "<span class=\'badge badge-warning\'>'..i18n("system_stats.influxdb_health_yellow")..'</span>", "descr" : "<small>'..i18n("system_stats.influxdb_health_yellow_descr")..'</small>"},')
    print('"red" : {"status" : "<span class=\'badge badge-danger\'>'..i18n("system_stats.influxdb_health_red")..'</span>", "descr" : "<small>'..i18n("system_stats.influxdb_health_red_descr")..'</small>"},')
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
       
elseif(page == "historical" and ts_creation) then
   local schema = _GET["ts_schema"] or "influxdb:storage_size"
   local selected_epoch = _GET["epoch"] or ""
   local tags = {ifid = getSystemInterfaceId()}
   url = url.."&page=historical"

   drawGraphs(getSystemInterfaceId(), schema, tags, _GET["zoom"], url, selected_epoch, {
      timeseries = {
      {schema="influxdb:storage_size",                      label=i18n("traffic_recording.storage_utilization")},
      {schema="influxdb:memory_size",                       label=i18n("about.ram_memory")},
      {schema="influxdb:write_successes",                   label=i18n("system_stats.write_througput")},
      {schema="influxdb:exports",                           label=i18n("system_stats.exports_label"),
       value_formatter = {"export_rate", "exports_format"},
       metrics_labels = {i18n("system_stats.exports_label")}},
      {schema="influxdb:exported_points",                   label=i18n("system_stats.exported_points")},
      {schema="influxdb:dropped_points",                    label=i18n("system_stats.dropped_points")},
      {schema="custom:infludb_exported_vs_dropped_points",  label=i18n("system_stats.exported_vs_dropped_points"),
       custom_schema = {
	  bases = {"influxdb:exported_points", "influxdb:dropped_points"},
	  types = {"area", "line"}, axis = {1,2},
       },
       metrics_labels = {i18n("system_stats.exported_points"), i18n("system_stats.dropped_points")},
      },
      {schema="influxdb:rtt",                               label=i18n("graphs.num_ms_rtt")},
   }})
elseif((page == "alerts") and isAdministrator()) then
   local old_ifname = ifname
   local influxdb = ts_utils.getQueryDriver()
   interface.select(getSystemInterfaceId())

   _GET["ifid"] = getSystemInterfaceId()
   _GET["entity"] = alert_consts.alertEntity("influx_db")

   drawAlerts()

   interface.select(old_ifname)
end

-- #######################################################

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
