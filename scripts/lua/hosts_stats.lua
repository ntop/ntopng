--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils_generic"
require "lua_utils_gui"
require "check_redis_prefs"

local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')

-- Context of the SPA route of this full page load (router.js computes it on the
-- SPA navigations from the menu.lua flags, not loaded yet at this time)
page_route_context = {
    isNedge = (ntop.isnEdge and ntop.isnEdge()) or false,
    is_enterprise_l = (ntop.isEnterpriseL and ntop.isEnterpriseL()) or false,
    has_vlans = interface.hasVLANs(),
}

local menu = page_utils.menu_entries.hosts
if isASNModeEnabled() then
    menu = page_utils.menu_entries.hosts_asn_mode
end
page_utils.print_header_and_set_active_menu_entry(menu)

-- Active hosts and local hosts report are SPA views (page-hosts-list.vue,
-- page-local-hosts-report.vue), see router.js; the original page is in
-- attic/scripts/lua/hosts_stats.lua
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
