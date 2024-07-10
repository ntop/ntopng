--
-- (C) 2013-24 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local template_utils = require("template_utils")
local page_utils = require "page_utils"
local json = require "dkjson"
require "lua_utils"

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.autonomous_systems)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_navbar(i18n("as_stats.autonomous_systems"), ntop.getHttpPrefix() .. "/lua/as_stats.lua", {{
    active = page == "overview" or not page,
    page_name = "overview",
    label = "<i class=\"fas fa-lg fa-home\"  data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" ..
        i18n("as_stats.autonomous_systems") .. "\"></i>"
}})

local context = {
    ifid = interface.getId()
}

local json_context = json.encode(context)

template_utils.render("pages/vue_page.template", {
    vue_page_name = "PageAsStats",
    page_context = json_context
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
