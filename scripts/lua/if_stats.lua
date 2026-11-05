--
-- (C) 2013-26 - ntop.org
--
-- Interface details. The views are drawn by the SPA (http_src/vue/router.js, route
-- /lua/if_stats.lua, IF_TABS): this page only prints the header and the menu.
-- The original page: attic/scripts/lua/if_stats.lua
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(
    isLightView() and page_utils.menu_entries.interface_lightview or page_utils.menu_entries.interface,
    { ifname = getHumanReadableInterfaceName(ifname) })

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
