--
-- (C) 2013-23 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local graph_utils = require("graph_utils")

sendHTTPContentTypeHeader('text/html')
page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.system_status)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

graph_utils.drawNewGraphs({ ifid = interface.getId()})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
