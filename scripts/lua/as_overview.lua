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
local graph_utils = require "graph_utils"

local asn = _GET["asn"]
local criteria_as = _GET["criteria_as"]
local tableId = "ingress_egress_as_stats"
local page = _GET["page"]
local content_type = _GET["type"]

if (not criteria_as) or (criteria_as == "ingress_egress_traffic_criteria") then
    tableId = "ingress_egress_as_stats" 
elseif (criteria_as == "as_traffic_criteria") then
    tableId = "traffic_as_stats"
else
    tableId = "transit_as_stats"
end

sendHTTPContentTypeHeader('text/html')
page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.autonomous_systems)
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_navbar(i18n("asn_id",{id = format_utils.formatASN(asn)}), ntop.getHttpPrefix() .. "/lua/as_overview.lua", {{
    active = (page == "overview" or not page),
    url = ntop.getHttpPrefix() .. "/lua/as_overview.lua?asn=" .. asn .. "",
    page_name = "overview",
    label = "<i class=\"fas fa-lg fa-home\"  data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" ..
        i18n("as_overview.asn_exporters") .. "\"></i>"
}, {
    url = ntop.getHttpPrefix() .. "/lua/as_overview.lua?page=historical&asn=" .. asn .. "",
    active = page == "historical",
    page_name = "historical",
    label = "<i class='fas fa-lg fa-chart-area'></i>"
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

if page == "overview" or not page then
    template_utils.render("pages/vue_page.template", {
        vue_page_name = "PageAsOverview",
        page_context = json.encode({
            csrf = ntop.getRandomCSRFValue(),
            ifid = interface.getId(),
            isEnterpriseL = ntop.isEnterpriseL(),
            tableId = tableId,
            historical = content_type and content_type == "historical",
            showTimeseries = areASTimeseriesEnabled(interface.getId())
        })
    })
else
    local source_value_object = {
        asn = asn,
        ifid = interface.getId()
    }
    graph_utils.drawNewGraphs(source_value_object)
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
