--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils     = require "page_utils"
local json           = require "dkjson"
local template_utils = require "template_utils"
local protos_utils   = require "protos_utils"

sendHTTPContentTypeHeader('text/html')

if not isAdministratorOrPrintErr() then
  return
end

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.categories)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local page_name = _GET["page"] or "protocols"

page_utils.print_navbar(i18n("custom_categories.apps_and_categories"), ntop.getHttpPrefix() .. "/lua/admin/edit_categories.lua", {
  {
    active    = page_name == "protocols",
    page_name = "protocols",
    label     = i18n("applications"),
  },
  {
    active    = page_name == "categories",
    page_name = "categories",
    label     = i18n("categories"),
  },
})

local context = {
  page_csrf       = ntop.getRandomCSRFValue(),
  ifid            = interface.getId(),
  has_protos_file = protos_utils.hasProtosFile(),
  page_name       = page_name,
}

local json_context = json.encode(context)

template_utils.render("pages/vue_page.template", {
  vue_page_name = "PageEditCategories",
  page_context  = json_context
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
