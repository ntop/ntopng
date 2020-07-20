--
-- (C) 2020 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local page_utils = require "page_utils"
local json = require "dkjson"
local template_utils = require "template_utils"
local host_pools = require "host_pools"

local host_pool = host_pools:create()

sendHTTPContentTypeHeader('text/html')

if not haveAdminPrivileges() then return end
page_utils.set_active_menu_entry(page_utils.menu_entries.host_members)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_page_title(i18n("host_pools.host_members"))

-- ************************************* ------

local context = {
    template_utils = template_utils,
    json = json,
    pool = host_pool
}

print(template_utils.gen("pages/manage_host_members.template", context))

-- ************************************* ------

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
