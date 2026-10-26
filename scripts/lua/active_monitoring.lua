--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "check_redis_prefs"
local page_utils = require("page_utils")

-- ###########################################

if not isAllowedSystemInterface() then
    return
end

sendHTTPContentTypeHeader('text/html')

-- Context of the SPA route of this full page load (router.js computes it on the
-- SPA navigations from the menu.lua flags, not loaded yet at this time)
page_route_context = {
    is_am_active = ntop.getPrefs().active_monitoring,
    timeseries_enabled = areSystemTimeseriesEnabled(),
    alerts_enabled = areAlertsEnabled(),
    stats_ifid = -1,
}

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.active_monitoring)

-- Overview and charts are SPA views (page-active-monitoring.vue, page-stats-route.vue),
-- see router.js
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
