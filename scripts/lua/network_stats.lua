--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require("lua_utils")
local page_utils = require("page_utils")

sendHTTPContentTypeHeader("text/html")

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.networks)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- SPA route (see http_src/vue/router.js): AppShell's <router-view> renders
-- PageNetworks or PageSites client-side depending on ?page= (router.js's
-- componentByQuery). ifid/csrf come from boot context; areTsEnabled comes
-- from menu.lua's are_ts_enabled flag. PageTreemapNetworks (previously only
-- mounted when interface.getNetworksStats() had entries) is now always
-- mounted alongside PageNetworks -- it fetches its own data via REST and
-- handles the empty case itself, so the numNetworks>0 server-side gate
-- wasn't functionally necessary, just an avoid-empty-widget optimization.
-- The 2-tab navbar is defined in router.js's `navbar` field.

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
