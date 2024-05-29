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

if not isAdministratorOrPrintErr() then
    return
end

-- The order key is used to set an order for the rendered list in the page
local configuration_items
local page = _GET["page"]
local base_url = ntop.getHttpPrefix() .. "/lua/admin/manage_configurations.lua"

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.manage_configurations)
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_navbar(i18n('manage_configurations.manage_configuration'), base_url .. "?", {{
    active = page == "manage_configurations" or page == nil,
    page_name = "manage_configurations",
    label = i18n("manage_configurations.manage_configurations")
}, {
    -- url = base_url .. "?vlan_id=0&page=analysis&aggregation_criteria="..aggregation_criteria.."&draw="..draw.."&sort="..sort.."&order="..order.."&start="..start.."&length="..length,
    active = page == "manage_configurations_backup",
    page_name = "manage_configurations_backup",
    label = i18n("manage_configurations.manage_configurations_backup")
}})

if not ntop.isnEdge() then
    configuration_items = {
        all = {
            key = "all",
            label = i18n("manage_configurations.everything", {
                product = ntop.getInfo()["product"]
            }),
            order = 0
        },
        active_monitoring = {
            key = "active_monitoring",
            label = i18n("manage_configurations.active_monitoring_vs"),
            order = 2
        },
        checks = {
            key = "checks",
            label = i18n("manage_configurations.checks"),
            order = 3
        },
        notifications = {
            key = "notifications",
            label = i18n("manage_configurations.notifications"),
            order = 4
        },
        pool = {
            key = "pool",
            label = i18n("manage_configurations.pool_endpoint_recipients"),
            order = 5
        }
    }
else
    configuration_items = {
        all = {
            key = "all",
            label = i18n("manage_configurations.everything", {
                product = ntop.getInfo()["product"]
            }),
            order = 0
        },
        checks = {
            key = "checks",
            label = i18n("manage_configurations.checks"),
            order = 1
        }
    }
end

-- the infrastructure dashboard is available only in the Enterprise L
if ntop.isEnterpriseL() then
    configuration_items['infrastructure'] = {
        key = "infrastructure",
        label = i18n("manage_configurations.infrastructure_instances"),
        order = 6
    }
end

local selected_item = (table.has_key(configuration_items, _GET["item"]) and _GET["item"] or "all")

-- page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.manage_configurations)

-- append the menu above the page

-- if the selected page is snmp but we aren't in pro version
-- then block the user with an alert

-- page_utils.print_page_title(i18n("manage_configurations.manage_configurations"))
-- ************************************* ------

local user = _SESSION["user"]
local date_format = ntop.getPref("ntopng.user." .. user .. ".date_format")

if (page == "manage_configurations_backup") then
    template_utils.render("pages/manage_configurations_backup.template", {
        date_format = date_format
    })
else
    template_utils.render("pages/manage_configurations.template", {
        info = ntop.getInfo(),
        template_utils = template_utils,
        manage_configurations = {
            selected_item = selected_item,
            configuration_items = configuration_items
        }
    })
end
-- ************************************* ------

-- append the footer below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
