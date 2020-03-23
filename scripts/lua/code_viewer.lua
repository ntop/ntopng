--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path

-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"
local page_utils = require("page_utils")
local code_editor = require("code_editor")

sendHTTPContentTypeHeader('text/html')
page_utils.manage_system_interface()

local title = i18n("plugin_browser", {plugin_name = _GET["plugin_path"]})
local url = ntop.getHttpPrefix().."/lua/code_viewer.lua"

page_utils.set_active_menu_entry(page_utils.menu_entries.plugin_browser, {plugin_name = _GET["plugin_path"]})

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_navbar(title, url,
			{
			   {
			      active = true,
			      page_name = "overview",
			      label = "<i class=\"fas fa-lg fa-home\"></i>",
			   },
			}
)

code_editor.editor(_GET["plugin_file_path"], _GET["plugin_path"])

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
