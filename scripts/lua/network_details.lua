--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require("lua_utils")
local page_utils = require("page_utils")

local page = _GET["page"]

sendHTTPContentTypeHeader("text/html")

-- The page is rendered by the Vue app shell (see network_details.lua in router.js): hosts and
-- charts are SPA views, only the traffic report is still drawn here (legacyOnly tab)
-- Pro: the Networks entry is superseded by the Sites dashboard
page_utils.print_header_and_set_active_menu_entry(ntop.isPro() and page_utils.menu_entries.sites_dashboard
	or page_utils.menu_entries.networks)
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if page == "traffic_report" and hasTrafficReport() then
	package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/?.lua;" .. package.path
	local traffic_report = require("traffic_report")
	traffic_report.generate_traffic_report()
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
