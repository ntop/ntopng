--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require "page_utils"

sendHTTPContentTypeHeader('text/html')

-- The policies REST APIs are for administrators only (before the header: it prints its own page)
if not isAdministratorOrPrintErr() then
   return
end

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.device_protocols)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- pro/http_src/vue/page-edit-device-protocols.vue (SPA route, see router.js),
-- its context is rest/v2/get/device/protocols_context.lua

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
