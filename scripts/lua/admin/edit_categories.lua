--
-- (C) 2018 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local template = require "template_utils"
local categories_utils = require "categories_utils"
local lists_utils = require "lists_utils"
local page_utils = require("page_utils")
active_page = "admin"

sendHTTPContentTypeHeader('text/html')

local category_filter = _GET["l7proto"]
local ifId = getInterfaceId(ifname)

if not haveAdminPrivileges() then
  return
end

local tab = _GET["tab"] or "hosts"

page_utils.print_header(i18n("users.categories"))

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print("<hr>")
print("<h2>") print(i18n("users.categories")) print("</h2>")
print("<br>")

print [[
<ul id="n2n-nav" class="nav nav-tabs" role="tablist">]]

print('<li class="'.. ternary(tab ~= "protocols", "active", "") ..'"><a href="?tab=hosts">'.. i18n("categories") .. "</a>")
print('<li class="'.. ternary(tab == "protocols", "active", "") ..'"><a href="?tab=protocols">'.. i18n("protocols") .. "</a>")

print[[</ul>]]

print('<div class="tab-content">')

if tab == "protocols" then
  dofile(dirs.installdir .. "/scripts/lua/inc/edit_ndpi_applications.lua")
else
  dofile(dirs.installdir .. "/scripts/lua/inc/edit_categories.lua")
end

print('</div>')

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
