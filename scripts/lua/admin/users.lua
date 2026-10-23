--
-- (C) 2022 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')

local is_admin = isAdministrator()

-- Non-administrators are allowed in this page as well, but they only see (and
-- can edit) their own profile
if (not is_admin) and isEmptyString(_SESSION["user"] or "") then
   isAdministratorOrPrintErr()
   return
end

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.manage_users)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- The page is pro/http_src/vue/page-users.vue (SPA route), the data comes from
-- rest/v2/get/ntopng/users_list.lua and user.lua

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
