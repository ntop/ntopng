--
-- (C) 2020-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils     = require "page_utils"
local json           = require "dkjson"
local template_utils = require "template_utils"

if not isAdministratorOrPrintErr() then return end

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.license)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local context = {
   is_admin = isAdministrator(),
}

local json_context = json.encode(context)

template_utils.render("pages/vue_page.template", {
   vue_page_name = "PageLicense",
   page_context  = json_context
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
