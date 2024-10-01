--
-- (C) 2020-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/toasts/?.lua;" .. package.path

require "lua_utils"

local page_utils = require("page_utils")
local ui_utils = require("ui_utils")
local template = require "template_utils"
local json = require "dkjson"
local format_utils = require("format_utils")

if not isAdministratorOrPrintErr() then 
   return 
end

local url = ntop.getHttpPrefix() .. '/lua/limits.lua?'

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.limits)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_navbar(i18n("limits_page.limits"), url, {{
   active = true,
   page_name = "overview",
   label = "<i class=\"fas fa-lg fa-home\"></i>"
}})

template.render("pages/vue_page.template", { vue_page_name = "PageLimits", page_context = json.encode({}) })

-- append the menu below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
