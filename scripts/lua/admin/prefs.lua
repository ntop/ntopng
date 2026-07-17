--
-- (C) 2014-26 - ntop.org
--
-- New Vue-based preferences page — mounted at /lua/prefs_vue.lua
-- for side-by-side testing with the old /lua/admin/prefs.lua.
-- Does NOT modify the original file.
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "ntop_utils"

local auth       = require "auth"
local page_utils = require "page_utils"

-- Capability guard
if not auth.has_capability(auth.capabilities.preferences) then
   return redirect(ntop.getHttpPrefix() .. "/lua/index.lua")
end

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.preferences)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
