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

if not isAllowedSystemInterface() then
   return
end

sendHTTPContentTypeHeader('text/html')

page_utils.print_header()

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local page = _GET["page"] or "overview"
local url = ntop.getHttpPrefix() .. "/lua/system_stats.lua?ifid=" .. getInterfaceId(ifname)
local info = ntop.getInfo()
system_schemas = system_scripts.getAdditionalTimeseries("system")

print [[
  <nav class="navbar navbar-default" role="navigation">
  <div class="navbar-collapse collapse">
    <ul class="nav navbar-nav">
]]

print("<li><a href=\"#\">" .. i18n("system") .. "</a></li>\n")

if((page == "overview") or (page == nil)) then
   print("<li class=\"active\"><a href=\"#\"><i class=\"fa fa-home fa-lg\"></i></a></li>\n")
else
   print("<li><a href=\""..url.."&page=overview\"><i class=\"fa fa-home fa-lg\"></i></a></li>")
end

if(ts_utils.exists("process:memory")) then
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

if(page == "overview") then
   local storage_utils = require("storage_utils")

   print("<table class=\"table table-bordered table-striped\">\n")

   local system_rowspan = 1
   local system_host_stats = ntop.systemHostStat()

   if system_host_stats["cpu_load_percentage"] ~= nil then  system_rowspan = system_rowspan + 1 end
   if system_host_stats["mem_total"] ~= nil then system_rowspan = system_rowspan + 1 end

   if(info["pro.systemid"] and (info["pro.systemid"] ~= "")) then
      print("<tr><th rowspan="..system_rowspan.." width=5%>"..i18n("about.system").."</th></tr>\n")
   end

   if system_host_stats["cpu_load_percentage"] ~= nil then
      print("<tr><th nowrap>"..i18n("about.cpu_load").."</th><td><span id='cpu-load-pct'>...</span></td></tr>\n")
   end
   if system_host_stats["mem_total"] ~= nil then
      print("<tr><th nowrap>"..i18n("about.ram_memory").."</th><td><span id='ram-used'></span></td></tr>\n")
   end

   print("<tr><th rowspan=20>"..info["product"].."</th>")

   if(info.pid ~= nil) then
      print("<tr><th nowrap>PID (Process ID)</th><td>"..info.pid.."</td></tr>\n")
   end
   if system_host_stats["mem_ntopng_resident"] ~= nil then
      print("<tr><th nowrap>"..i18n("about.ram_memory").."</th><td><span id='ram-process-used'></span></td></tr>\n")
   end

   local storage_info = storage_utils.storageInfo()

   local storage_items = {}
   local classes = { "primary", "info", "warning", "success", "default" }
   local colors = { "blue", "salmon", "seagreen", "cyan", "green", "magenta", "orange", "red", "violet" }
   local col = 1
   local num_items = 0
   for if_id, if_info in pairs(storage_info.interfaces) do
     local item = {
       title = getInterfaceName(if_id),
       value = if_info.total,
       link = ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid=" .. if_id
     }
     if num_items < #classes then
       item.class = classes[num_items+1]
     else
       item.style = "background-image: linear-gradient(to bottom, "..colors[col].." 0%, dark"..colors[col].." 100%)"
       col = col + 1
       if col > #colors then col = 1 end
     end
     table.insert(storage_items, item)
     num_items = num_items + 1
   end

   if not ntop.isWindows() then
      print("<tr><th>"..i18n("traffic_recording.storage_utilization").."</th><td>")
      print(stackedProgressBars(storage_info.total, storage_items, nil, bytesToSize))
      print("</td></tr>\n")
   end

   print("<tr><th nowrap>"..i18n("about.last_log").."</th><td><code>\n")

   for i=1,32 do
       msg = ntop.listIndexCache("ntopng.trace", i)
       if(msg ~= nil) then
          print(noHtml(msg).."<br>\n")
       end
   end

   print("</code></td></tr>\n")


   print("</table>\n")
elseif(page == "historical") then
   local schema = _GET["ts_schema"] or "system:cpu_load"
   local selected_epoch = _GET["epoch"] or ""
   local tags = {}
   url = url.."&page=historical"

   drawGraphs(getSystemInterfaceId(), schema, tags, _GET["zoom"], url, selected_epoch, {
      timeseries = table.merge({
         {schema="system:cpu_load",            label=i18n("about.cpu_load")},
         {schema="process:memory",             label=i18n("graphs.process_memory")},
      }, system_schemas)
   })
elseif((page == "alerts") and isAdministrator()) then
   local old_ifname = ifname
   interface.select(getSystemInterfaceId())

   _GET["ifid"] = getSystemInterfaceId()
   _GET["entity_excludes"] = string.format("%u,%u",
      alertEntity("influx_db"), alertEntity("snmp_device"))

   drawAlerts({hide_filters = true})

   interface.select(old_ifname)
end

-- #######################################################

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
