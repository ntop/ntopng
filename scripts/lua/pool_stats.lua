--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "ntop_utils"

local page_utils = require "page_utils"

local have_nedge = ntop.isnEdge and ntop.isnEdge()

sendHTTPContentTypeHeader('text/html')

-- if not nedge use hosts_pools
local menu = not have_nedge and page_utils.menu_entries.host_pools or page_utils.menu_entries.users

page_utils.print_header_and_set_active_menu_entry(menu)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")


