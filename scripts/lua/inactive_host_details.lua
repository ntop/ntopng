--
-- (C) 2013-23 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local template_utils = require "template_utils"
local page_utils = require("page_utils")
sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.hosts)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local title = " "
local url = ntop.getHttpPrefix() .. "/lua/inactive_host_details.lua?"

page_utils.print_navbar(title, url, {{
    active = true,
    page_name = "overview",
    label = "<i class=\"fas fa-lg fa-home\"></i>"
}})

template_utils.render("pages/inactive_host_details.template", {
    ifid = interface.getId(),
    csrf = ntop.getRandomCSRFValue()
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
