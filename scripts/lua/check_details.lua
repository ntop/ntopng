--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
end

require "lua_utils"
local graph_utils = require "graph_utils"
local page_utils = require("page_utils")
local os_utils = require "os_utils"
local ts_utils = require "ts_utils"

local check     = _GET["check"]
local subdir     = _GET["subdir"]

local ifstats = interface.getStats()
local ifId = ifstats.id
local schema_prefix = ternary(subdir == "flow", "flow_check", "elem_check")
sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.scripts_config)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if((check == nil) or (subdir == nil)) then
   print("<div class=\"alert alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> check/subdir parameter is missing (internal error ?)</div>")
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
   return
end

if(not ts_utils.exists(schema_prefix .. ":duration", {ifid = ifId, check = check, subdir = subdir})) then
   print("<div class=\"alert alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> No available stats for user script "..check.."</div>")
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
   return
end

local nav_url = ntop.getHttpPrefix().."/lua/check_details.lua?ifid="..interface.getId()
local title = "User Script: "..check

page_utils.print_navbar(title, nav_url,
			{
			   {
			      active = page == "overview" or not page,
			      page_name = "overview",
			      label = "<i class=\"fas fa-home fa-lg\"></i>",
			   },
			}
)

local schema = _GET["ts_schema"] or "custom:".. schema_prefix ..":vs_total"
local selected_epoch = _GET["epoch"] or ""
local url = ntop.getHttpPrefix()..'/lua/check_details.lua?ifid='..ifId..'&check='..check..'&page=historical&subdir='..subdir

local tags = {
   ifid = ifId,
   check = check,
   subdir = subdir,
}

graph_utils.drawGraphs(ifId, schema, tags, _GET["zoom"], url, selected_epoch, {
   top_check = "top:".. schema_prefix ..":duration",

   timeseries = {
      {schema = "custom:" .. schema_prefix .. ":total_stats", label = i18n("internals.total_stats", {subdir = firstToUpper(subdir)}), metrics_labels = {i18n("duration")}},
      {
         schema = "custom:".. schema_prefix ..":vs_total",
         label = i18n("internals.script_stats", {script = check}),
         value_formatter = {"NtopUtils.fmillis"},
         value_formatter2 = {"NtopUtils.fint"},
         metrics_labels = {
            i18n("internals.script_duration", {script = check}),
            i18n("internals.total_duration", {subdir = firstToUpper(subdir)}),
            i18n("internals.script_num_calls", {script = check}),
         },
      }
   }
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
