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
local plugins_utils = require("plugins_utils")
local alert_consts = require("alert_consts")
require("graph_utils")
require("alert_utils")

local ts_creation = plugins_utils.timeseriesCreationEnabled()

if not isAllowedSystemInterface() then
   return
end

sendHTTPContentTypeHeader('text/html')

page_utils.print_header()

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
			      hidden = not ts_creation or not ts_utils.exists("process:resident_memory", {ifid=getSystemInterfaceId()}),
			      active = page == "historical",
			      page_name = "historical",
			      label = "<i class='fas fa-lg fa-chart-area'></i>",
			   },
			   {
			      hidden = interface.isPcapDumpInterface() or not isAdministrator() or not areAlertsEnabled(),
			      active = page == "alerts",
			      page_name = "alerts",
			      label = "<i class=\"fas fa-exclamation-triangle fa-lg\"></i>",
			   },
			}
)

-- #######################################################

if(page == "overview") then
   local storage_utils = require("storage_utils")

   print("<table class=\"table table-bordered table-striped\">\n")

   local system_rowspan = 1
   local system_host_stats = ntop.systemHostStat()

   if system_host_stats["cpu_load"] ~= nil then  system_rowspan = system_rowspan + 1 end
   if system_host_stats["mem_total"] ~= nil then system_rowspan = system_rowspan + 1 end

   if(info["pro.systemid"] and (info["pro.systemid"] ~= "")) then
      print("<tr><th rowspan="..system_rowspan.." width=5%>"..i18n("about.system").."</th></tr>\n")
   end

   if system_host_stats["cpu_load"] ~= nil then
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

   if not ntop.isWindows() then
      local storage_info = storage_utils.storageInfo()

      local storage_items = {}

      local classes = { "primary", "info", "warning", "success", "secondary" }
      local colors = { "blue", "salmon", "seagreen", "cyan", "green", "magenta", "orange", "red", "violet" }

      -- interfaces
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

      -- system
      local item = {
	 title = i18n("system"),
	 value = storage_info.other,
	 link = ""
      }
      item.style = "background-image: linear-gradient(to bottom, grey 0%, darkgrey 100%)"
      table.insert(storage_items, item)

      print("<tr><th>"..i18n("traffic_recording.storage_utilization").."</th><td>")
      print("<span>"..i18n("volume")..": "..dirs.workingdir.." ("..storage_info.volume_dev..")</span><br />")
      print(stackedProgressBars(storage_info.volume_size, storage_items, i18n("available"), bytesToSize))
      print("</td></tr>\n")

      if storage_info.pcap_volume_dev ~= nil then
	 storage_items = {}

	 -- interfaces
	 col = 1
	 num_items = 0
	 for if_id, if_info in pairs(storage_info.interfaces) do
	    local item = {
	       title = getInterfaceName(if_id),
	       value = if_info.pcap,
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

	 -- system
	 local item = {
	    title = i18n("system"),
	    value = storage_info.pcap_other,
	    link = ""
	 }
	 item.style = "background-image: linear-gradient(to bottom, grey 0%, darkgrey 100%)"
	 table.insert(storage_items, item)

	 print("<tr><th>"..i18n("traffic_recording.storage_utilization_pcap").."</th><td>")
	 print("<span>"..i18n("volume")..": "..dirs.workingdir.." ("..storage_info.pcap_volume_dev..")</span><br />")
	 print(stackedProgressBars(storage_info.pcap_volume_size, storage_items, i18n("available"), bytesToSize))
	 print("</td></tr>\n")
      end
   end

   print("<tr><th nowrap>"..i18n("about.last_log").."</th><td><code>\n")
   for i=0,32 do
       msg = ntop.listIndexCache("ntopng.trace", i)
       if(msg ~= nil) then
	  print(noHtml(msg).."<br>\n")
       end
   end
   print("</code></td></tr>\n")

   print("</table>\n")
elseif(page == "historical" and ts_creation) then
   local schema = _GET["ts_schema"] or "system:cpu_load"
   local selected_epoch = _GET["epoch"] or ""
   local tags = {ifid = getSystemInterfaceId()}
   url = url.."&page=historical"

   drawGraphs(getSystemInterfaceId(), schema, tags, _GET["zoom"], url, selected_epoch, {
      timeseries = {
	    {schema="system:cpu_load",            label=i18n("about.cpu_load"), metrics_labels = {i18n("about.cpu_load")}, value_formatter = {"ffloat"}},
	    {schema="process:resident_memory",    label=i18n("graphs.process_memory")},
      }
   })
elseif((page == "alerts") and isAdministrator()) then
   local cur_id = interface.getId()
   interface.select(getSystemInterfaceId())

   _GET["ifid"] = getSystemInterfaceId()
   _GET["entity_excludes"] = string.format("%u,%u,%u",
      alert_consts.alertEntity("influx_db"), alert_consts.alertEntity("snmp_device"),
      alert_consts.alertEntity("pinged_host"))

   drawAlerts()

   interface.select(tostring(cur_id))
end

-- #######################################################

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
