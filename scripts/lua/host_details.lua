--
-- (C) 2013-26 - ntop.org
--
-- Details of a host: SPA view (route in pro/http_src/vue/router.js, page-host-details-route.vue;
-- data from rest/v2/get/host/*). The old page is in attic/.

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.hosts)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
