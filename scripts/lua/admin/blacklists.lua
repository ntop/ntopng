--
-- (C) 2013-26 - ntop.org
--
-- trace_script_duration = true
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
sendHTTPContentTypeHeader('text/html')

-- Check permissions. This has to come BEFORE the page header and the menu:
-- isAdministratorOrPrintErr() renders its own shell plus an "Access forbidden"
-- notice, whereas bailing out after them left the user on a blank page.
if not isAdministratorOrPrintErr() then
  return
end

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.category_lists)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- Overview and charts are SPA views (page-blacklists.vue, page-stats-route.vue),
-- see router.js

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
