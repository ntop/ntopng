--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")

if not isAllowedSystemInterface() then
	return
end

sendHTTPContentTypeHeader("text/html")

-- Context of the SPA route of this full page load (router.js computes it on the
-- SPA navigations from the menu.lua flags, not loaded yet at this time)
local info = ntop.getInfo()
local ts_driver = ntop.getPref("ntopng.prefs.timeseries_driver")
page_route_context = {
	timeseries_enabled = areSystemTimeseriesEnabled(),
	alerts_enabled = areAlertsEnabled(),
	is_admin = isAdministrator(),
	is_oem = info.oem or false,
	product = info.product,
	stats_ifid = -1,
	-- page-internals.vue: the system interface queues, periodic activities and checks
	is_sys_iface = true,
	ifid = -1,
	show_hash_tables = false,
	show_periodic_activities = true,
	show_checks = true,
	show_queues = true,
	ts_driver = (ts_driver ~= "" and ts_driver) or "rrd",
}

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.system_status)

-- The views are SPA views (page-system-status.vue, page-stats-route.vue, page-internals.vue),
-- see router.js
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
