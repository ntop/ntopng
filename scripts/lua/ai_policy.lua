--
-- (C) 2013-26 - ntop.org
--
-- AI Security Policy Manager page.
-- Renders the PageAiPolicy Vue component.

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils     = require("page_utils")
local template_utils = require("template_utils")
local json           = require("dkjson")

if not isAdministrator() then
   return
end

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.active_monitoring)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local ifid = interface.getId()

local json_context = json.encode({
   ifid      = ifid,
   csrf      = ntop.getRandomCSRFValue(),
   is_admin  = isAdministrator(),
})

template_utils.render("pages/vue_page.template", {
   vue_page_name = "PageAiPolicy",
   page_context  = json_context
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
