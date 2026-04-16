--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require "page_utils"
local json = require "dkjson"
local template_utils = require "template_utils"

local info = ntop.getInfo()

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.bgp_looking_glass)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_navbar(i18n('bgp_looking_glass'), ntop.getHttpPrefix() .. "/lua/bgp_looking_glass.lua", {{
   hidden = false,
   active = true,
   page_name = "overview",
   label = "<i class=\"fas fa-lg fa-home\"></i>"
}})

local context = {}
local json_context = json.encode(context)

template_utils.render("pages/vue_page.template", {
    vue_page_name = "PageBGPLookingGlass",
    page_context = json_context
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
