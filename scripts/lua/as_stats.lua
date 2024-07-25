--
-- (C) 2013-24 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local template_utils = require("template_utils")
local graph_utils = require "graph_utils"
local page_utils = require "page_utils"
local json = require "dkjson"
require "lua_utils"

local page = _GET["page"]
local asn = _GET["asn"]

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.autonomous_systems)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_navbar(i18n("as_stats.autonomous_systems"), ntop.getHttpPrefix() .. "/lua/as_stats.lua", {{
    active = page == "overview" or not page,
    page_name = "overview",
    label = "<i class=\"fas fa-lg fa-home\"  data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" ..
        i18n("as_stats.autonomous_systems") .. "\"></i>"
}, {
    active = page == "historical",
    hidden = isEmptyString(asn),
    page_name = "historical",
    label = "<i class='fas fa-lg fa-chart-area'></i>"
}})

local context = {
    ifid = interface.getId()
}

local json_context = json.encode(context)
if page == "overview" or not page then
    template_utils.render("pages/vue_page.template", {
        vue_page_name = "PageAsStats",
        page_context = json_context
    })
else
    local source_value_object = {
        asn = tonumber(asn),
        ifid = interface.getId()
    }
    graph_utils.drawNewGraphs(source_value_object)
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
