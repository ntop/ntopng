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

interface.select(ifname)

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.manage_users)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
dofile(dirs.installdir .. "/scripts/lua/inc/users.lua")
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
dofile(dirs.installdir .. "/scripts/lua/inc/password_dialog.lua")

if is_admin then
   dofile(dirs.installdir .. "/scripts/lua/inc/add_user_dialog.lua")
   dofile(dirs.installdir .. "/scripts/lua/inc/delete_user_dialog.lua")
end
