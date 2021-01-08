--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local alert_consts = require("alert_consts")
local page_utils = require("page_utils")
local template = require "template_utils"

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.alert_definitions)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local context = {
   page_utils = page_utils,
   alert_consts = alert_consts,
}

print(template.gen("pages/alerts/defs_overview.template", context))

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

