--
-- (C) 2013-26 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local ts_info = require("timeseries_info")
local page_utils = require("page_utils")
local template = require "template_utils"

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.ts_definitions)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local context = {
   page_utils = page_utils,
   ts_info = ts_info,
}

print(template.gen("pages/ts_overview.template", context))

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")


