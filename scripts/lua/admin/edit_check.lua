--
-- (C) 2021-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils     = require "page_utils"
local json           = require "dkjson"
local template_utils = require "template_utils"
local auth           = require "auth"

if not auth.has_capability(auth.capabilities.checks) then
   return
end

if not isAdministratorOrPrintErr() then
   return
end

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.scripts_config)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local check_subdir = _GET["subdir"] or "flow"
local script_key   = _GET["script_key"] or ""

page_utils.print_navbar(i18n("edit_check.hooks_config"), ntop.getHttpPrefix() .. "/lua/admin/edit_check.lua", {
   {
      active    = true,
      page_name = "edit",
      label     = i18n("edit_check.hooks_config"),
   },
})

local context = {
   check_subdir = check_subdir,
   script_key   = script_key,
   page_csrf    = ntop.getRandomCSRFValue(),
   ifid         = interface.getId(),
   back_url     = ntop.getHttpPrefix() .. "/lua/admin/edit_configset.lua?subdir=" .. check_subdir,
}

template_utils.render("pages/vue_page.template", {
   vue_page_name = "PageEditCheck",
   page_context  = json.encode(context),
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
