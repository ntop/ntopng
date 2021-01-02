--
-- (C) 2013-21 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path

require "lua_utils"
local template = require "template_utils"
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.alerts_status)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- ########################################################################################

-- MENU
local url = ntop.getHttpPrefix() .. "/lua/system_alerts_stats.lua?ifid=" .. getSystemInterfaceId()
local title = i18n("system_alerts_status")

page_utils.print_navbar(title, url, {
			   {
			      active = page == "overview" or not page,
			      page_name = "overview",
			      label = "<i class=\"fas fa-lg fa-home\"></i>"
			   },
})

if page == "overview" or page == nil then
   local context = {
      template_utils = template,
   }

   print(template.gen('pages/system_alerts_stats.template', context))
end -- if page

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
