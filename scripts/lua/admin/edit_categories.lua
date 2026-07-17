--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require "page_utils"

sendHTTPContentTypeHeader('text/html')

if not isAdministratorOrPrintErr() then
  return
end

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.categories)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
