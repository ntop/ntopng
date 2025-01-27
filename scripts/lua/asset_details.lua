--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local template_utils = require "template_utils"
local page_utils = require("page_utils")
sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.hosts)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local title = " "
local url = ntop.getHttpPrefix() .. "/lua/asset_details.lua?"

page_utils.print_navbar(title, url, {{
    active = true,
    page_name = "overview",
    label = "<i class=\"fas fa-lg fa-home\"></i>"
}})

local json = require "dkjson" 
local json_context = json.encode({
    ifid = interface.getId(),
    csrf = ntop.getRandomCSRFValue()
})
template_utils.render("pages/vue_page.template", { vue_page_name = "PageAssetDetails", page_context = json_context })


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
