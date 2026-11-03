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

sendHTTPContentTypeHeader('text/html')

-- Context of the SPA route of this full page load (router.js computes it on the
-- SPA navigations from the menu.lua flags, not loaded yet at this time)
local ts_driver = ntop.getPref("ntopng.prefs.timeseries_driver")
page_route_context = {
   is_admin = isAdministrator(),
   -- page-internals.vue: every interface (no ifid), hash tables, periodic activities and checks
   is_sys_iface = true,
   ifid = require("dkjson").null,
   show_hash_tables = true,
   show_periodic_activities = true,
   show_checks = true,
   show_queues = false,
   ts_driver = (ts_driver ~= "" and ts_driver) or "rrd",
}

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.interfaces_status)

-- Overview and internals are SPA views (page-system-interfaces.vue, page-internals.vue),
-- see router.js
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
