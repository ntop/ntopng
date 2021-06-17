--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local checks = require("checks")
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.checks_dev)

-- #######################################################

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print(
   [[
        <div class='row'>
            <div class='col-12'>
]]
)

page_utils.print_page_title('Checks')

checks.printUserScripts()

print(
   [[
        </div>
            </div>
]]
)


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

