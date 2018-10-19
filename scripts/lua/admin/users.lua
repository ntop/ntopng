--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPContentTypeHeader('text/html')

if(haveAdminPrivileges()) then
   interface.select(ifname)

   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
   
   active_page = "admin"
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
   dofile(dirs.installdir .. "/scripts/lua/inc/users.lua")
   dofile(dirs.installdir .. "/scripts/lua/inc/password_dialog.lua")
   dofile(dirs.installdir .. "/scripts/lua/inc/add_user_dialog.lua")
   dofile(dirs.installdir .. "/scripts/lua/inc/delete_user_dialog.lua")

   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
end
