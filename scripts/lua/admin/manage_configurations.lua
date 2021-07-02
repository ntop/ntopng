--
-- (C) 2020 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local page_utils = require "page_utils"
local json = require "dkjson"
local template_utils = require "template_utils"

sendHTTPContentTypeHeader('text/html')

if not isAdministratorOrPrintErr() then return end

-- The order key is used to set an order for the rendered list in the page
local configuration_items

if not ntop.isnEdge() then
   configuration_items = {
      all = {key = "all", label = i18n("manage_configurations.everything", {product = ntop.getInfo()["product"]}), order = 0 },
      snmp = {key = "snmp", label = i18n("manage_configurations.snmp"), order = 1},
      active_monitoring = {key = "active_monitoring", label = i18n("manage_configurations.active_monitoring"), order = 2},
      checks = {key = "checks", label = i18n("manage_configurations.checks"), order = 3},
      notifications = {key = "notifications", label = i18n("manage_configurations.notifications"), order = 4},
      pool = {key = "pool", label = i18n("manage_configurations.pool_endpoint_recipients"), order = 5},
   }
else
   configuration_items = {
      all = {key = "all", label = i18n("manage_configurations.everything", {product = ntop.getInfo()["product"]}), order = 0 },
      checks = {key = "checks", label = i18n("manage_configurations.checks"), order = 1},
   }
end

-- the infrastructure dashboard is available only in the Enterprise L
if ntop.isEnterpriseL() then
   configuration_items['infrastructure'] = {key = "infrastructure", label = i18n("manage_configurations.infrastructure_instances"), order = 6}
end

local selected_item = (table.has_key(configuration_items, _GET["item"]) and _GET["item"] or "all")

page_utils.set_active_menu_entry(page_utils.menu_entries.manage_configurations)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- if the selected page is snmp but we aren't in pro version
-- then block the user with an alert

page_utils.print_page_title(i18n("manage_configurations.manage_configurations"))
-- ************************************* ------


print(template_utils.gen("pages/manage_configurations.template", {
    info = info,
    template_utils = template_utils,
    manage_configurations = {
        selected_item = selected_item,
        configuration_items = configuration_items,
    }
}))

-- ************************************* ------

-- append the footer below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
