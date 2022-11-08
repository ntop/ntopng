--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

require "lua_utils"
local page_utils = require("page_utils")
local script_manager = require("script_manager")
local internals_utils = require "internals_utils"
local cpu_utils = require("cpu_utils")
local ts_utils = require "ts_utils"
local graph_utils = require("graph_utils")

local ts_creation = script_manager.systemTimeseriesEnabled()

if not isAllowedSystemInterface() then
   return
end

sendHTTPContentTypeHeader('text/html')
page_utils.set_active_menu_entry(page_utils.menu_entries.system_status)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local page = _GET["page"] or "overview"
local url = ntop.getHttpPrefix() .. "/lua/system_stats.lua?ifid="..interface.getId()
local title = i18n("system")
local info = ntop.getInfo()

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
			      active = page == "internals",
			      page_name = "internals",
			      label = "<i class=\"fas fa-lg fa-wrench\"></i>",
			   },
			}
)

-- #######################################################

if(page == "overview") then
   local storage_utils = require("storage_utils")

   print("<div class='table-responsive-lg table-responsive-md'>")
   print("<table class=\"table table-bordered table-striped\">\n")

   local system_rowspan = 1
   local ntopng_rowspan = 20
   local system_host_stats = cpu_utils.systemHostStats()
   local has_system = false

   if system_host_stats["cpu_load"] ~= nil then  system_rowspan = system_rowspan + 1; has_system = true end
   if system_host_stats["mem_total"] ~= nil then system_rowspan = system_rowspan + 1; has_system = true end
   if system_host_stats["cpu_states"] and system_host_stats["cpu_states"]["iowait"] then system_rowspan = system_rowspan + 1; has_system = true end

   if has_system then
      print("<tr><th rowspan="..system_rowspan.." width=5%>"..i18n("about.system").."</th></tr>\n")
   end

   if system_host_stats["cpu_load"] ~= nil then
      local chart_available = ts_utils.exists("system:cpu_load", {ifid = getSystemInterfaceId()})
      print("<tr><th nowrap>"..i18n("about.cpu_load").." "..ternary(chart_available, "<A HREF='"..url.."&page=historical&ts_schema=system:cpu_load'><i class='fas fa-chart-area fa-sm'></i></A>", "").."</th><td><span id='cpu-load-pct'>" .. round(system_host_stats["cpu_load"], 2) .. "</span></td></tr>\n")
   end

   if system_host_stats["cpu_states"] and system_host_stats["cpu_states"]["iowait"] then
      local chart_available = ts_utils.exists("system:cpu_states", {ifid = getSystemInterfaceId()})
      local iowait = i18n("about.iowait") .. ": " .. round(formatValue(system_host_stats["cpu_states"]["iowait"]), 2) .. "%"
      local active = i18n("about.active") .. ": " .. round(formatValue(system_host_stats["cpu_states"]["user"] + system_host_stats["cpu_states"]["system"] + system_host_stats["cpu_states"]["nice"] + system_host_stats["cpu_states"]["irq"] + system_host_stats["cpu_states"]["softirq"] + system_host_stats["cpu_states"]["guest"] + system_host_stats["cpu_states"]["guest_nice"]), 2) .. "%"
      local idle = i18n("about.idle") .. ": " .. round(formatValue(system_host_stats["cpu_states"]["idle"] + system_host_stats["cpu_states"]["steal"]), 2) .. "%"
      print("<tr><th nowrap>"..i18n("about.cpu_states").." "..ternary(chart_available, "<A HREF='"..url.."&page=historical&ts_schema=system:cpu_states'><i class='fas fa-chart-area fa-sm'></i></A>", "").."</th><td><span id='cpu-states'>" .. iowait .. " / " .. active .. " / " .. idle .. "</span></td></tr>\n")
   end

   if system_host_stats["mem_total"] ~= nil then
    local ram_used = system_host_stats["mem_used"]
    local ram_used_ratio = i18n("ram_used") .. ": " .. tostring(round((ram_used / system_host_stats["mem_total"]) * 100 * 100) / 100) .. "%";
    local ram_available = i18n("ram_available") .. ": " .. bytesToSize((system_host_stats["mem_total"] - ram_used) * 1024)
    local ram_total = i18n("ram_total") .. ": " .. bytesToSize(system_host_stats["mem_total"] * 1024)

    print("<tr><th nowrap>"..i18n("about.ram_memory").."</th><td><span id='ram-used'>" .. ram_used_ratio .. " / " .. ram_available .. " / " .. ram_total .. "</span></td></tr>\n")
   end

   print("<tr><th rowspan=".. ntopng_rowspan ..">"..info["product"].."</th>")

   if(info.pid ~= nil) then
      print("<tr><th nowrap>PID (Process ID)</th><td>"..info.pid.."</td></tr>\n")
   end
   if system_host_stats["mem_ntopng_resident"] ~= nil then
      local chart_available = ts_utils.exists("process:resident_memory", {ifid = getSystemInterfaceId()})
      print("<tr><th nowrap>"..i18n("about.ram_memory").." "..ternary(chart_available, "<A HREF='"..url.."&page=historical&ts_schema=process:resident_memory'><i class='fas fa-chart-area fa-sm'></i></A>", "").."</th><td><span id='ram-process-used'>" .. i18n("ram_used") .. ": " .. bytesToSize(system_host_stats["mem_ntopng_resident"] * 1024) .. "</span></td></tr>\n")
   end

   if areAlertsEnabled() then
      local chart_available = ts_utils.exists("process:num_alerts", {ifid = getSystemInterfaceId()})
      print("<tr><th nowrap>"..i18n("details.alerts").." "..ternary(chart_available, "<A HREF='"..url.."&page=historical&ts_schema=process:num_alerts'><i class='fas fa-chart-area fa-sm'></i></A>", "").."</th><td>"..i18n("about.alert_queries")..": <span id='alerts-queries'>" .. round(system_host_stats["alerts_queries"]) .. "</span> / "..i18n("about.alerts_stored")..": <span id='stored-alerts'>" .. round(system_host_stats["written_alerts"]) .. "</span> / "..i18n("about.alerts_dropped")..": <span id='dropped-alerts'>" .. round(system_host_stats["dropped_alerts"]) .. "</span></td></tr>\n")
   end

   print("<tr id='storage-info-tr'><th>"..i18n("traffic_recording.storage_utilization").."</th><td>")
   print("<div id='storage-info'></div>")
   print("</td></tr>")

   print("<tr id='storage-pcap-info-tr'><th>"..i18n("traffic_recording.storage_utilization_pcap").."</th><td>")
   print("<div id='storage-pcap-info'></div>")
   print("</td></tr>")

   if not info.oem then
      print("<tr><th nowrap>"..i18n("about.last_log").."</th><td><div class='scrollable-log'><code>\n")
      for i=0,32 do
         msg = ntop.listIndexCache("ntopng.trace", i)
         if(msg ~= nil) then

            local text = noHtml(msg)

            -- encapsule the ERROR or WARNING string in a badge
            -- so the log are more visible
            if text:find("ERROR") then
               text = text:gsub("(ERROR)(:)", "<span class='badge bg-danger'>%1</span>")
            elseif text:find("WARNING") then
               text = text:gsub("(WARNING)(:)", "<span class='badge bg-warning'>%1</span>")
            end

            print(text)
            print("<br>")
         end
      end
      print("</code></div></td></tr>\n")
   end

   print("</table>")
   print("</div>")

   print [[
   <script>
   var storageRefresh = function() {
     $.ajax({
       type: 'GET',
       url: ']]
print (ntop.getHttpPrefix())
print [[/lua/system_stats_data.lua',
       data: { },
       success: function(rsp) {
	 if(rsp.storage !== undefined) {
	   $('#storage-info').html(rsp.storage);
           $("#storage-info-tr").show();
         }
	 if(rsp.pcap_storage !== undefined) {
	   $('#storage-pcap-info').html(rsp.pcap_storage);
           $("#storage-pcap-info-tr").show();
         }
       }
     });
   }
   $("#storage-info-tr").hide();
   $("#storage-pcap-info-tr").hide();
   storageRefresh();
   </script>
   ]]

elseif(page == "historical" and ts_creation) then
  graph_utils.drawNewGraphs(nil, interface.getId())
elseif page == "internals" then
   internals_utils.printInternals(getSystemInterfaceId(), false --[[ hash tables ]], true --[[ periodic activities ]], true --[[ checks]], true --[[ queues --]])
end

-- #######################################################

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
