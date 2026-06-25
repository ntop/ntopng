--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local template_utils = require("template_utils")
local json = require("dkjson")

sendHTTPContentTypeHeader('text/html')
page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.devices)
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_navbar(i18n("mac_details.mac_list"), ntop.getHttpPrefix() .. "/lua/macs_stats_vue.lua", {{
    active = page == "overview" or not page,
    page_name = "overview",
    label = "<i class=\"fas fa-lg fa-home\"  data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" ..
        i18n("mac_details.mac_list") .. "\"></i>"
}})

local ifstats = interface.getStats()

local context = {
    ifid = ifstats.id,
    csrf = ntop.getRandomCSRFValue(),
    isnEdge = ntop.isnEdge and ntop.isnEdge()
}

local json_context = json.encode(context)

template_utils.render("pages/vue_page.template", {
    vue_page_name = "PageMacsList",
    page_context  = json_context
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
