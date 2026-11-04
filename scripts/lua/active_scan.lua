--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")

-- Administrators only, as every active scan REST (and the menu entry).
-- Checked before sendHTTPContentTypeHeader: the redirect must be the first output
if not isAdministrator() then
    print(ntop.httpRedirect(ntop.getHttpPrefix() .. "/lua/index.lua"))
    return
end

local page = _GET["page"]

sendHTTPContentTypeHeader('text/html')

-- The printable report (opened by the Print action of the report, without menu)
-- is drawn here; every other view is an SPA view (see router.js)
if (page == "report" or page == "reports") and toboolean(_GET["printable"]) then
    local json = require("dkjson")
    local template = require("template_utils")
    local title = i18n("hosts_stats.page_scan_hosts.report.title")
    -- ascan_utils.get_scan_all_dates, read here not to load ascan_utils
    local scan_dates = json.decode(ntop.getCache("ntopng.vs.report_dates") or "")

    if scan_dates and scan_dates.start_date then
        title = string.format("%s (%s - %s)", title, scan_dates.start_date, scan_dates.end_date)
    end

    page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.active_scan)
    template.render("pages/vue_page.template", { vue_page_name = "Dashboard", page_context = json.encode({
        ifid = interface.getId(),
        page = "vs-report",
        title = title,
        template = "ascan_result",
        printable = true,
        csrf = ntop.getRandomCSRFValue(),
        template_endpoint = ntop.getHttpPrefix() .. "/lua/pro/rest/v2/get/report/template/data.lua",
        template_list_endpoint = ntop.getHttpPrefix() .. "/lua/pro/rest/v2/get/report/template/list.lua",
    }) })
    return
end

-- Context of the SPA route of this full page load (router.js computes it on the
-- SPA navigations from the menu.lua flags, not loaded yet at this time)
page_route_context = {
    ifid = interface.getId(),
    is_pro = (ntop.isPro and ntop.isPro()) or false,
    is_enterprise_l = (ntop.isEnterpriseL and ntop.isEnterpriseL()) or false,
    alerts_enabled = areAlertsEnabled(),
    stats_ifid = -1,
    stats_source_value_object = { is_va = true },
}

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.active_scan)

-- The views are SPA views (page-active-scan-route.vue, page-open-ports.vue,
-- page-stats-route.vue), see router.js
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
