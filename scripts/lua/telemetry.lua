--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local telemetry_utils = require "telemetry_utils"
local page = _GET["page"] or "overview"

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.telemetry)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

--[[
Create Menu Bar with buttons
--]]

local nav_url = ntop.getHttpPrefix().."/lua/telemetry.lua?ifid="..interface.getId()
local title = i18n("telemetry")

page_utils.print_navbar(title, url,
			{
			   {
			      active = page == "overview" or not page,
			      page_name = "overview",
			      label = "<i class=\"fas fa-home fa-lg\"></i>",
			   },
			}
)

if page == "overview" then
   telemetry_utils.print_overview()
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
