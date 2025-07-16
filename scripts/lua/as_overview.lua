--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local page_utils = require("page_utils")
local template_utils = require "template_utils"
local format_utils = require "format_utils"

local asn = _GET["asn"]

sendHTTPContentTypeHeader('text/html')
page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.autonomous_systems)
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_navbar(i18n("asn_id",{id = format_utils.formatASN(asn)}), ntop.getHttpPrefix() .. "/lua/as_overview.lua", {{
    active = true,
    page_name = "overview",
    label = "<i class=\"fas fa-lg fa-home\"  data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" ..
        i18n("as_overview.asn_exporters") .. "\"></i>"
}, { 
    url = ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?asn=" .. asn .. "",
    active = page == "asn_hosts",
    page_name = "asn_hosts",
    label = "<i class=\"fas fa-laptop fa-lg\"></i>"
}, { 
    url = ntop.getHttpPrefix() .. "/lua/flows_stats.lua?asn=" .. asn .. "",
    active = page == "asn_flows",
    page_name = "asn_flows",
    label = "<i class=\"fas fa-stream fa-lg\"></i>"
}, { 
    url = ntop.getHttpPrefix() .. "/lua/as_stats.lua?show_as=all",
    active = page == "as_stats",
    page_name = "as_stats",
    label = "<i class=\"fas fa-globe fa-lg\"></i>"
}})

template_utils.render("pages/vue_page.template", {
    vue_page_name = "PageAsOverview",
    page_context = json.encode({
        csrf = ntop.getRandomCSRFValue(),
        ifid = interface.getId()
    })
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
