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

if not haveAdminPrivileges() then return end

local selected_item = _GET["item"] or "snmp"

page_utils.set_active_menu_entry(page_utils.menu_entries.import_export_config)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- if the selected page is snmp but we aren't in pro version
-- then block the user with an alert

page_utils.print_page_title(i18n("import_export.import_export"))
-- ************************************* ------

-- TODO: replace button with links in SNMP and AM

print(template_utils.gen("pages/import_export_config.template", {
    template_utils = template_utils,
    import_export = {
        selected_item = selected_item,
        configuration_items = {
            {key = "all", label = i18n("import_export.everything") },
            {key = "snmp", label = i18n("import_export.snmp")},
            {key = "active_monitoring", label = i18n("import_export.active_monitoring")},
            -- {key = "user_scripts", label = i18n("import_export.user_scripts")},
            -- {key = "pool_endpoint_recipients", label = i18n("import_export.pool_endpoint_recipients")},
        }
    }
}))

-- ************************************* ------

-- append the footer below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")