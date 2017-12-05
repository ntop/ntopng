--
-- (C) 2013-17 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

require "lua_utils"
local host_pools_utils = require "host_pools_utils"

-- Administrator check
if not isAdministrator() then
  return
end

local username = _GET["username"]
--local pool_id = host_pools_utils.usernameToPoolId(username)
local page = _GET["page"] or "settings"

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print[[<ul class="nav nav-tabs">
  <li ]] print(ternary(page == "settings", 'class="active"', '')) print[[><a href="?page=settings&username=]] print(username) print[[">]] print(i18n("users.settings")) print[[</a></li>
  <li ]] print(ternary(page == "protocols", 'class="active"', '')) print[[><a href="?page=protocols&username=]] print(username) print[[">]] print(i18n("protocols")) print[[</a></li>
  <li ]] print(ternary(page == "categories", 'class="active"', '')) print[[><a href="?page=categories&username=]] print(username) print[[">]] print(i18n("users.categories")) print[[</a></li>
</ul><br>]]

-- ###################################################################

local function printSettingsPage()
  print("TODO settings page")
end

-- ###################################################################

local function printProtocolsPage()
  print("TODO protocols page")
end

-- ###################################################################

local function printCategoriesPage()
  print("TODO categories page")
end

-- ###################################################################

if page == "settings" then
  printSettingsPage()
elseif page == "protocols" then
  printProtocolsPage()
elseif page == "categories" then
  printCategoriesPage()
end

-- ###################################################################

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
