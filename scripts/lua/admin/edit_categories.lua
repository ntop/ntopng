--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local template = require "template_utils"
local categories_utils = require "categories_utils"
local lists_utils = require "lists_utils"
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')


local category_filter = _GET["l7proto"]
local ifId = getInterfaceId(ifname)

if not isAdministratorOrPrintErr() then
  return
end

local tab = _GET["tab"] or "protocols"

page_utils.set_active_menu_entry(page_utils.menu_entries.categories)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_page_title(i18n("custom_categories.apps_and_categories"))

print [[
<div class='card'>
<div class='card-header'>
<ul id="n2n-nav" class="nav nav-tabs card-header-tabs" role="tablist">]]

print('<li class="nav-item '.. ternary(tab == "protocols", "active", "") ..'"><a class="nav-link '.. ternary(tab == "protocols", "active", "") ..'" href="?tab=protocols">'.. i18n("applications") .. "</a>")
print('<li class="nav-item '.. ternary(tab ~= "protocols", "active", "") ..'"><a class="nav-link '.. ternary(tab ~= "protocols", "active", "") ..'" href="?tab=categories">'.. i18n("categories") .. "</a>")

print[[</ul></div>]]

print('<div class="card-body tab-content">')

if tab == "protocols" then
  dofile(dirs.installdir .. "/scripts/lua/inc/edit_ndpi_applications.lua")
else
  dofile(dirs.installdir .. "/scripts/lua/inc/edit_categories.lua")
end

print('</div>')
print('</div>')

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
