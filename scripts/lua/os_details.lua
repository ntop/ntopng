--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local graph_utils = require "graph_utils"

local page_utils = require("page_utils")

local OS        = _GET["os"]
local page      = _GET["page"]

interface.select(ifname)
local ifstats = interface.getStats()
local ifId = ifstats.id
local ts_utils = require("ts_utils")

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.countries)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(OS == nil) then
   print("<div class=\"alert alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> ".. i18n("os_details.os_parameter_missing_message") .. "</div>")
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
   return
end

if(not ts_utils.exists("os:traffic", {ifid=ifId, os=OS})) then
   print("<div class=\"alert alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> " .. i18n("os_details.no_available_stats_for_os",{os=OS}) .. "</div>")
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
   return
end

--[[
Create Menu Bar with buttons
--]]
local nav_url = ntop.getHttpPrefix().."/lua/os_details.lua?country="..OS
local title = i18n("os_details.os") .. ": "..OS

   page_utils.print_navbar(title, nav_url,
			   {
			      {
				 active = page == "historical" or not page,
				 page_name = "historical",
				 label = "<i class='fas fa-lg fa-chart-area'></i>",
			      },
			   }
   )

--[[
Selectively render information pages
--]]
if page == "historical" then
    local schema = _GET["ts_schema"] or "os:traffic"
    local selected_epoch = _GET["epoch"] or ""
    local url = ntop.getHttpPrefix()..'/lua/os_details.lua?ifid='..ifId..'&os='..OS..'&page=historical'

    local tags = {
      ifid = ifId,
      os = OS,
    }

    graph_utils.drawGraphs(ifId, schema, tags, _GET["zoom"], url, selected_epoch, {
      timeseries = {
        {schema="os:traffic", label=i18n("traffic"), split_directions = true},
      }
    })
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
