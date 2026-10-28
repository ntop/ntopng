--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')

-- ?ifid= selects the interface, as the old page did
local ifid = _GET["ifid"]
if not isEmptyString(ifid) then
    interface.select(ifid)
end

local menu = page_utils.menu_entries.active_flows
if ntop.isnEdge and ntop.isnEdge() then
    menu = page_utils.menu_entries.nedge_flows
elseif isASNModeEnabled() then
    menu = page_utils.menu_entries.active_flows_asn_mode
end
page_utils.print_header_and_set_active_menu_entry(menu)

-- The page and its tabs (flows, aggregation, geomap) are an SPA view (page-flows-route.vue),
-- see router.js; the original page is in attic/scripts/lua/flows_stats.lua
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
