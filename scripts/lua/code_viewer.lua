--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path

-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"
local page_utils = require("page_utils")
local  code_editor = require("code_editor")

sendHTTPContentTypeHeader('text/html')

page_utils.print_header()

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

code_editor.editor(_GET["lua_script_path"])

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
