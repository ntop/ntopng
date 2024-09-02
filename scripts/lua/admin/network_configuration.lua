--
-- (C) 2020 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "ntop_utils"

local page_utils = require "page_utils"
local json = require "dkjson"
local template_utils = require("template_utils")
local ifid = interface.getId()

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.network_config)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local ifstats = interface.getStats()
local probes = ifstats.probes

page_utils.print_navbar(i18n("checks.network_configuration"), ntop.getHttpPrefix() .. "/lua/admin/network_configuration.lua", {{
    url = ntop.getHttpPrefix() .. "/lua/admin/network_configuration.lua",
    active = true,
    page_name = "assets_inventory",
    label = "<i class=\"fas fa-lg fa-home\"  data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" ..
    i18n("checks.network_configuration") .. "\"></i>"
}})

local context = {
    ifid = interface.getId(),
    csrf = ntop.getRandomCSRFValue()
}

local json_context = json.encode(context)

template_utils.render("pages/vue_page.template", {
    vue_page_name = "PageAssetsInventory",
    page_context = json_context
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
