--
-- (C) 2013-20 - ntop.org
--

-- This an example page provided by this plugin
-- menu.lua adds a link to this page into the ntopng main menu.

-- Changes to this script must be applied by reloading the plugins from
-- http://127.0.0.1:3000/lua/plugins_overview.lua

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
active_page = "system_stats"

require "lua_utils"
local page_utils = require("page_utils")
local plugins_utils = require("plugins_utils")

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.example_plugin)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local page = _GET["page"] or "overview"

local url = plugins_utils.getUrl("example_page.lua") .. "?ifid=" .. getInterfaceId(ifname)
local title = i18n("example.custom_page_title")

page_utils.print_navbar(title, url,
  {
     {
	active = page == "overview" or not page,
	page_name = "overview",
	label = "<i class=\"fas fa-lg fa-home\"></i>",
     },
     {
	hidden = false,
	active = page == "config",
	page_name = "config",
	label = "<i class='fas fa-lg fa-cog'></i>",
     },
  }
)

-- #######################################################

if(page == "overview") then
  print("<h2>Overview Page</h2>")
  print[[
  <i>Put the content here<i>
]]
elseif(page == "config") then
  print("<h2>Config Page</h2>")
  print[[
  <i>Put the content here<i>
]]
end

-- #######################################################

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
