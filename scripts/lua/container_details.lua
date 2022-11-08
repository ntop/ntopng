--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local graph_utils = require "graph_utils"

local page_utils = require("page_utils")
local format_utils = require("format_utils")

local container      = _GET["container"]
local page           = _GET["page"]

local ifId = interface.getId()
local ts_utils = require("ts_utils")

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.containers)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if not container or not ts_utils.exists("container:num_flows", {ifid=ifId, container=container}) then
   print("<div class=\"alert alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> " .. i18n("no_data_available") .. "</div>")
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
   return
end

local container_label = format_utils.formatContainerFromId(container)

--[[
Create Menu Bar with buttons
--]]
local nav_url = ntop.getHttpPrefix().."/lua/container_details.lua?container="..container
local title = i18n("containers_stats.container") .. ": "..container_label

page_utils.print_navbar(title, nav_url,
			{
			   {
			      hidden = not ts_utils.exists("container:num_flows", {ifid=ifId, container=container}),
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
  graph_utils.drawNewGraphs(container, interface.getId())
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
