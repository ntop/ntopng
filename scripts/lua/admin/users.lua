--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPContentTypeHeader('text/html')

if(haveAdminPrivileges()) then
   interface.select(ifname)

   is_captive_portal_active = isCaptivePortalActive() and not ntop.isnEdge()

   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
   
   active_page = "admin"
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
   
   dofile(dirs.installdir .. "/scripts/lua/inc/users.lua")

   local ifstats = interface.getStats()
   local is_captive_portal_enabled = ntop.getPrefs()["is_captive_portal_enabled"]
   if(ifstats.inline and not(is_captive_portal_enabled)) and not ntop.isnEdge() then
      print('<small><b>'..i18n("if_stats_overview.note")..':</b> ') print(i18n("manage_users.enable_captive_portal", {url=ntop.getHttpPrefix() ..'/lua/admin/prefs.lua?tab=bridging'})) print('.</small>')
   end

   dofile(dirs.installdir .. "/scripts/lua/inc/password_dialog.lua")
   dofile(dirs.installdir .. "/scripts/lua/inc/add_user_dialog.lua")
   dofile(dirs.installdir .. "/scripts/lua/inc/delete_user_dialog.lua")

   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
end
