--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path

-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"
local page_utils = require("page_utils")
local code_editor = require("code_editor")

sendHTTPContentTypeHeader('text/html')

local title = string.gsub(i18n("script_browser", {script_name = _GET["script_path"]}), "/lua/", "")
local referal_script_page = _GET["referal_url"]

page_utils.set_active_menu_entry(page_utils.menu_entries.script_browser, {script_name = _GET["script_path"]})

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_page_title(title)
code_editor.editor(_GET["script_file_path"], _GET["script_path"], referal_script_page)

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
