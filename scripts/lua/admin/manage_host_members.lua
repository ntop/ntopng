--
-- (C) 2020-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require "page_utils"

sendHTTPContentTypeHeader('text/html')

-- The pool member REST APIs are for administrators only (before the header: it prints its own page)
if not isAdministratorOrPrintErr() then
    return
end

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.host_pools)
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- pro/http_src/vue/page-manage-host-members.vue (SPA route, see router.js)

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
