--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local graph_utils = require "graph_utils"

local page_utils = require("page_utils")
local format_utils = require("format_utils")

local pod            = _GET["pod"]
local page           = _GET["page"]

interface.select(ifname)
local ifId = getInterfaceId(ifname)

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.pods)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
 
if not pod or not areContainersTimeseriesEnabled(ifId) then
   print("<div class=\"alert alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> " .. i18n("no_data_available") .. "</div>")
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
   return
end

--[[
Create Menu Bar with buttons
--]]
local nav_url = ntop.getHttpPrefix().."/lua/pod_details.lua?pod="..pod
local title = i18n("containers_stats.pod") .. ": "..pod
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
  graph_utils.drawNewGraphs(pod, interface.getId())
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
