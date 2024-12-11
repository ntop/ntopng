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

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.network_config)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local page = _GET["page"]

page_utils.print_navbar(i18n("checks.network_configuration"),
    ntop.getHttpPrefix() .. "/lua/admin/network_configuration.lua", { {
    active = (page == nil or page =='assets_inventory'),
    page_name = "assets_inventory",
    label = "<i class=\"fas fa-lg fa-home\"  data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" ..
        i18n("checks.network_configuration") .. "\"></i>"
}, {
    active = (page == "policy"),
    page_name = "policy",
    hidden = not ntop.isEnterpriseL(),
    label = i18n("network_configuration.network_policy")
}})

local context = {
    ifid = interface.getId(),
    csrf = ntop.getRandomCSRFValue()
}

local json_context = json.encode(context)

if (page == nil or page =='assets_inventory') then
    template_utils.render("pages/vue_page.template", {
        vue_page_name = "PageNetworkConfiguration",
        page_context = json_context
    })
else
    template_utils.render("pages/vue_page.template", {
        vue_page_name = "PageNetworkPolicy",
        page_context = json_context
    })
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
