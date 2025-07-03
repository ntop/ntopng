--
-- (C) 2013-24 - ntop.org
--
-- trace_script_duration = true
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local template = require "template_utils"
local page_utils = require("page_utils")
local page = _GET["page"] or 'overview'
local base_url = ntop.getHttpPrefix() .. "/lua/admin/blacklists.lua"
sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.category_lists)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
  
page_utils.print_navbar("Alerts Geomap", base_url .. "?", {{
    active = page == "overview" or page == nil,
    page_name = "overview",
    label = "<i class=\"fas fa-lg fa-home\"></i>"
}})


local json_context = json.encode({
    csrf = ntop.getRandomCSRFValue()
})
template.render("pages/vue_page.template", {
    vue_page_name = "PageAlertsGeoMap",
    page_context = json_context
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
