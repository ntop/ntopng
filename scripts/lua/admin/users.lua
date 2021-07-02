--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')


if(isAdministratorOrPrintErr()) then
   interface.select(ifname)

   page_utils.set_active_menu_entry(page_utils.menu_entries.manage_users)

   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
   dofile(dirs.installdir .. "/scripts/lua/inc/users.lua")
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
   dofile(dirs.installdir .. "/scripts/lua/inc/password_dialog.lua")
   dofile(dirs.installdir .. "/scripts/lua/inc/add_user_dialog.lua")
   dofile(dirs.installdir .. "/scripts/lua/inc/delete_user_dialog.lua")
end
