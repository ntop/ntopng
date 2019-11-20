--
-- (C) 2013-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
active_page = "system_stats"

require "lua_utils"
local page_utils = require("page_utils")
local ts_utils = require("ts_utils")
local alert_consts = require("alert_consts")
local system_scripts = require("system_scripts_utils")
require("graph_utils")
require("alert_utils")

local ts_creation = system_scripts.timeseriesCreationEnabled()

if not isAllowedSystemInterface() then
   return
end

sendHTTPContentTypeHeader('text/html')

page_utils.print_header()

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local probe = system_scripts.getSystemProbe("redis")
local page = _GET["page"] or "overview"
local url = system_scripts.getPageScriptPath(probe) .. "?ifid=" .. getInterfaceId(ifname)
system_schemas = system_scripts.getAdditionalTimeseries("redis")

print [[
  <nav class="navbar navbar-default" role="navigation">
  <div class="navbar-collapse collapse">
    <ul class="nav navbar-nav">
]]

print("<li><a href=\"#\">" .. "Redis" .. "</a></li>\n")

if((page == "overview") or (page == nil)) then
   print("<li class=\"active\"><a href=\"#\"><i class=\"fa fa-home fa-lg\"></i></a></li>\n")
else
   print("<li><a href=\""..url.."&page=overview\"><i class=\"fa fa-home fa-lg\"></i></a></li>")
end

if((page == "stats") or (page == nil)) then
   print("<li class=\"active\"><a href=\"#\"><i class=\"fa fa-wrench fa-lg\"></i></a></li>\n")
else
   print("<li><a href=\""..url.."&page=stats\"><i class=\"fa fa-wrench fa-lg\"></i></a></li>")
end

if ts_creation then
   if(page == "historical") then
      print("<li class=\"active\"><a href=\""..url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
   else
      print("<li><a href=\""..url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
   end
end

if isAdministrator()
-- and system_scripts.hasAlerts({entity = alert_consts.alertEntity("redis")}))
then
   -- if(page == "alerts") then
   --    print("\n<li class=\"active\"><a href=\"#\">")
   -- else
   --    print("\n<li><a href=\""..url.."&page=alerts\">")
   -- end

   -- print("<i class=\"fa fa-warning fa-lg\"></i></a>")
   -- print("</li>")
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

   print("<tr><td nowrap width='30%'><b>".. i18n("system_stats.health") .."</b><br><small>"..i18n("system_stats.redis.short_desc_redis_health").."</small></td><td></td><td><img class=\"redis-info-load\" border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber><span id=\"redis-health\"></span></td></tr>\n")

   -- No need to determine whether the chart exists for this as memory is always fetched straigth from redis
   local storage_chart_available = ts_creation and ts_utils.exists("redis:memory", tags)
   print("<tr><td nowrap width='30%'><b>".. i18n("about.ram_memory") .."</b><br><small>"..i18n("system_stats.redis.short_desc_redis_ram_memory").."</small></td>")
   print("<td class='text-center' width=5%>")
   print(ternary(storage_chart_available, "<A HREF='"..url.."&page=historical&ts_schema=redis:memory'><i class='fa fa-lg fa-area-chart'></i></A>", ""))
   print("</td><td><img class=\"redis-info-load\" border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber><span id=\"redis-info-memory\"></span></td></tr>\n")

   local keys_chart_available = ts_creation and ts_utils.exists("redis:keys", tags)
   print("<tr><td nowrap width='30%'><b>".. i18n("system_stats.redis.redis_keys") .."</b><br><small>"..i18n("system_stats.redis.short_desc_redis_keys").."</small></td>")
   print("<td class='text-center' width=5%>")
   print(ternary(keys_chart_available, "<A HREF='"..url.."&page=historical&ts_schema=redis:keys'><i class='fa fa-area-chart fa-lg'></i></A>", ""))
   print("</td><td><img class=\"redis-info-load\" border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber><span id=\"redis-info-keys\"></span></td></tr>\n")

   print[[<script>

 var last_keys, last_memory
 var health_descr = {
]]
   print('"green" : {"status" : "<span class=\'label label-success\'>'..i18n("system_stats.redis.redis_health_green")..'</span>", "descr" : "<small>'..i18n("system_stats.redis.redis_health_green_descr")..'</small>"},')
   print('"red" : {"status" : "<span class=\'label label-danger\'>'..i18n("system_stats.redis.redis_health_red")..'</span>", "descr" : "<small>'..i18n("system_stats.redis.redis_health_red_descr", {product = ntop.getInfo()["product"]})..'</small>"},')
      print[[
 };

 function refreshRedisStats() {
  $.get("]] print(ntop.getHttpPrefix()) print[[/lua/get_redis_info.lua", function(info) {
     $(".redis-info-load").hide();

     if(typeof info.health !== "undefined" && health_descr[info.health]) {
       $("#redis-health").html(health_descr[info.health]["status"] + "<br>" + health_descr[info.health]["descr"]);
     }
     if(typeof info.dbsize !== "undefined") {
       $("#redis-info-keys").html(formatValue(info.dbsize) + " ");
       if(typeof last_keys !== "undefined")
	 $("#redis-info-keys").append(drawTrend(info.dbsize, last_keys));
       last_keys = info.dbsize;
     }
     if(typeof info.memory !== "undefined") {
       $("#redis-info-memory").html(bytesToVolume(info.memory) + " ");
       if(typeof last_memory !== "undefined")
	 $("#redis-info-memory").append(drawTrend(info.memory, last_memory));
       last_memory = info.memory;
     }
  }).fail(function() {
     $(".redis-info-load").hide();
  });
 }

setInterval(refreshRedisStats, 5000);
refreshRedisStats();
 </script>
 ]]
   print("</table>\n")
elseif(page == "stats") then

   print [[
<div id="table-redis-stats"></div>
<script type='text/javascript'>

$("#table-redis-stats").datatable({
   title: "",
   perPage: 100,
   hidePerPage: true,
   url: "]] print(ntop.getHttpPrefix()) print[[/lua/get_redis_stats.lua",
   columns: [
     {
       field: "column_key",
       hidden: true,
       css: {
         width: '15%',
       }
     }, {
       field: "column_command",
       sortable: true,
       title: "]] print(i18n("please_wait_page.command")) print[[",
       css: {
         width: '15%',
       }
     }, {
       title: "]] print(i18n("chart")) print[[",
       field: "column_chart",
       hidden: ]] if not ts_creation then print("true") else print("false") end print[[,
       sortable: false,
       css: {
         textAlign: 'center',
         width: '5%',
       }
     }, {
       title: "]] print(i18n("system_stats.redis.tot_calls")) print[[",
       field: "column_hits",
       sortable: true,
       css: {
         textAlign: 'right'
       }
     }
   ], tableCallback: function() {
      datatableInitRefreshRows($("#table-redis-stats"), "column_key", 5000, {"column_hits": addCommas});
   }
});
</script>
 ]]
   
elseif(page == "historical" and ts_creation) then
   local schema = _GET["ts_schema"] or "redis:memory"
   local selected_epoch = _GET["epoch"] or ""
   local tags = {ifid = getSystemInterfaceId(), command = _GET["redis_command"]}
   url = url.."&page=historical"

   drawGraphs(getSystemInterfaceId(), schema, tags, _GET["zoom"], url, selected_epoch, {
       top_redis_hits = "top:redis:hits",
		 timeseries = system_schemas,
   })
elseif((page == "alerts") and isAdministrator()) then
   local old_ifname = ifname
   interface.select(getSystemInterfaceId())

   _GET["ifid"] = getSystemInterfaceId()
   -- _GET["entity"] = alert_consts.alertEntity("redis")

   drawAlerts()

   interface.select(old_ifname)
end

-- #######################################################

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
