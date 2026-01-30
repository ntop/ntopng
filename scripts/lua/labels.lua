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
page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.labels)
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local page = _GET["page"]

page_utils.print_navbar(i18n("labels_page.labels"), ntop.getHttpPrefix() .. "/lua/labels.lua", {{
    active = page == "overview" or page == nil,
    page_name = "overview",
    label = "<i class=\"fas fa-lg fa-home\"  data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" ..
        i18n("labels_page.labels") .. "\"></i>"
},{
    active = page == "exporter_sites",
    hidden = not ntop.isEnterpriseL(),
    page_name = "exporter_sites",
    label = i18n("exporter_sites_page.exporter_sites")
}})

local ifstats = interface.getStats()

local context = {
    ifid = ifstats.id,
    csrf = ntop.getRandomCSRFValue(),
}

local json_context = json.encode(context)

if page == "exporter_sites" then
    template_utils.render("pages/vue_page.template", {
        vue_page_name = "PageExporterSites",
        page_context  = json_context
    })
else
    template_utils.render("pages/vue_page.template", {
        vue_page_name = "PageLabels",
        page_context  = json_context
    })
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
