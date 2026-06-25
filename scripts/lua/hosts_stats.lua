--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
require "lua_utils_generic"
require "lua_utils_gui"
require "check_redis_prefs"
-- Instantiate host pools

local page_utils = require("page_utils")
local template_utils = require("template_utils")
local have_nedge = ntop.isnEdge and ntop.isnEdge()

local host_ts_available = areHostTimeseriesEnabled()
local is_asn_mode_enabled = isASNModeEnabled()

sendHTTPContentTypeHeader('text/html')
local menu = page_utils.menu_entries.hosts

if is_asn_mode_enabled then
    menu = page_utils.menu_entries.hosts_asn_mode
end

page_utils.print_header_and_set_active_menu_entry(menu)
local asn = _GET["asn"]
local page = _GET["page"] or 'active_hosts'
local base_url = ntop.getHttpPrefix() .. "/lua/hosts_stats.lua"

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_navbar(i18n("hosts"), base_url .. "?", {{
    active = page == "active_hosts" or page == nil,
    page_name = "active_hosts",
    label = i18n('active_hosts')
}, {
    hidden = not host_ts_available or not (ntop.isEnterpriseXL and ntop.isEnterpriseXL()) or is_asn_mode_enabled,
    active = page == "local_hosts_report",
    page_name = "local_hosts_report",
    label = i18n("local_hosts_report")
}, {
    hidden = not areASTimeseriesEnabled(ifid) or not asn,
    active = page == "exporters_stats",
    page_name = "exporters_stats",
    label = i18n("as_info"),
    url = ntop.getHttpPrefix() .. "/lua/as_overview.lua?asn=" .. (asn or 0)
}})


if page == "active_hosts" then
    local json = require "dkjson" 
    local vlans = interface.getVLANsList()
    local json_context = json.encode({
        ifid = interface.getId(),
        has_vlans = (vlans ~= nil),
        csrf = ntop.getRandomCSRFValue(),
        isNedge = have_nedge
    })
    template_utils.render("pages/vue_page.template", { vue_page_name = "PageHostsList", page_context = json_context })
elseif page == "local_hosts_report" then
    local json = require "dkjson"
    local json_context = json.encode({
        ifid = interface.getId(),
        csrf = ntop.getRandomCSRFValue()
    })
    template_utils.render("pages/vue_page.template", { vue_page_name = "PageLocalHostsReport", page_context = json_context }) 
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
