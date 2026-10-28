--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require "page_utils"

sendHTTPContentTypeHeader('text/html')

local menu = isASNModeEnabled() and page_utils.menu_entries.bgp_looking_glass_asn or page_utils.menu_entries.bgp_looking_glass

page_utils.print_header_and_set_active_menu_entry(menu)

-- The page is an SPA view (page-bgp-looking-glass.vue), see router.js;
-- the original page is in attic/scripts/lua/bgp_looking_glass.lua
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
