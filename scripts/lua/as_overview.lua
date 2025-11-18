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
local as_utils = require "as_utils"
local auth = require "auth"

local asn = _GET["asn"]
local criteria_as = _GET["criteria_as"]
local tableId = "ingress_egress_as_stats"
local page = _GET["page"]
local is_asn_mode_enabled = isASNModeEnabled()

if (not criteria_as) or (criteria_as == "traffic_between_ases") then
    tableId = "traffic_between_ases"
else
    tableId = "ingress_egress_as_stats"
end

sendHTTPContentTypeHeader('text/html')

if not is_asn_mode_enabled then
    page_utils.print_header_and_set_active_menu_entry(
        page_utils.menu_entries.autonomous_systems)
else
    page_utils.print_header_and_set_active_menu_entry(
        page_utils.menu_entries.autonomous_systems_asn_mode)
end
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_navbar(i18n("asn_id", {id = format_utils.formatASN(asn)}),
                        ntop.getHttpPrefix() .. "/lua/as_overview.lua", {
    {
        active = (page == "overview" or not page),
        url = ntop.getHttpPrefix() .. "/lua/as_overview.lua?asn=" .. asn .. "",
        page_name = "overview",
        label = "<i class=\"fas fa-lg fa-home\"  data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" ..
            i18n("as_overview.asn_exporters") .. "\"></i>"
    }, {
        url = ntop.getHttpPrefix() ..
            "/lua/as_overview.lua?page=historical&asn=" .. asn .. "",
        active = page == "historical",
        page_name = "historical",
        label = "<i class='fas fa-lg fa-chart-area' data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" ..
            i18n("prefs.timeseries") .. "\"></i>"
    }, {
        url = ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?asn=" .. asn .. "",
        active = page == "asn_hosts",
        page_name = "asn_hosts",
        label = "<i class=\"fas fa-laptop fa-lg\" data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" ..
            i18n("hosts") .. "\"></i>"
    }, {
        url = ntop.getHttpPrefix() .. "/lua/flows_stats.lua?asn=" .. asn .. "",
        active = page == "asn_flows",
        page_name = "asn_flows",
        label = "<i class=\"fas fa-stream fa-lg\" data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" ..
            i18n("flows") .. "\"></i>"
    }, {
        url = ntop.getHttpPrefix() .. "/lua/as_stats.lua?show_as=all",
        active = page == "as_stats",
        page_name = "as_stats",
        label = "<i class=\"fas fa-globe fa-lg\" data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" ..
            i18n("as_stats.autonomous_systems") .. "\"></i>"
    }, {
        hidden = not areAlertsEnabled() or not auth.has_capability(auth.capabilities.alerts),
        url = ntop.getHttpPrefix() .. "/lua/alert_stats.lua?page=as&status=engaged&asn="..asn .."%3Beq",
        active = page == "alerts",
        page_name = "alerts",
        label = "<i class=\"fas fa-lg fa-exclamation-triangle\" data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" ..
            i18n("alerts_dashboard.alerts") .. "\"></i>"
    }
})

if page == "overview" or not page then
    local show_historical = false
    local first_seen = 0
    -- Get the first record time, if any
    if ntop.isClickHouseEnabled() then
        show_historical = true
        local res = interface.execSQLQuery(
                        "SELECT FIRST_SEEN FROM hourly_asn ORDER BY FIRST_SEEN ASC LIMIT 1")
        if res and type(res) == "table" and #res > 0 then
            first_seen = tonumber(res[1]["FIRST_SEEN"])
        end
    end

    template_utils.render("pages/vue_page.template", {
        vue_page_name = "PageAsOverview",
        page_context = json.encode({
            csrf = ntop.getRandomCSRFValue(),
            ifid = interface.getId(),
            configuration = as_utils.getASNConfiguration(asn),
            isEnterpriseXL = ntop.isEnterpriseXL(),
            tableId = tableId,
            historical = show_historical,
            first_date_epoch = first_seen,
            showTimeseries = areASTimeseriesEnabled(interface.getId())
        })
    })
else
    local source_value_object = {asn = asn, ifid = interface.getId()}
    graph_utils.drawNewGraphs(source_value_object)
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
