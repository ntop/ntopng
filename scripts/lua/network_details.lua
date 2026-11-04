--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require("lua_utils")
local page_utils = require("page_utils")

local page = _GET["page"]

sendHTTPContentTypeHeader("text/html")

-- The page is rendered by the Vue app shell (see network_details.lua in router.js): hosts,
-- charts and traffic report are SPA views
-- Pro: the Networks entry is superseded by the Sites dashboard
page_utils.print_header_and_set_active_menu_entry(ntop.isPro() and page_utils.menu_entries.sites_dashboard
	or page_utils.menu_entries.networks)
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
