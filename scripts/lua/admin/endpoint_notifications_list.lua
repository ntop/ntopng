--
-- (C) 2019-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')

if not isAdministratorOrPrintErr() then
   return
end

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.endpoint_recipients)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- The page is pro/http_src/vue/page-notifications.vue (SPA route), the data comes from
-- rest/v2/get/notification/*.lua

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
