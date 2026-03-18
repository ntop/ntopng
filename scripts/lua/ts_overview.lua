--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils     = require "page_utils"
local json           = require "dkjson"
local template_utils = require "template_utils"

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.ts_definitions)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_navbar(i18n("about.ts_defines"), ntop.getHttpPrefix() .. "/lua/ts_overview.lua", {
  {
    active    = true,
    page_name = "overview",
    label     = i18n("overview"),
  }
})

local context = {}

template_utils.render("pages/vue_page.template", {
  vue_page_name = "PageTsOverview",
  page_context  = json.encode(context)
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
