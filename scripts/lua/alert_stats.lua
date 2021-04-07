--
-- (C) 2020 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require "page_utils"
local ui_utils = require "ui_utils"
local json = require "dkjson"
local template_utils = require "template_utils"

-- select the default page
local page = _GET["page"] or 'host'

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.detected_alerts)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local url = ntop.getHttpPrefix() .. "/lua/alert_stats.lua?"
page_utils.print_navbar(i18n("alerts_dashboard.alerts"), url, {
    {
        active = page == "host",
        page_name = "host",
        label = "Hosts",
    },
    {
        active = page == "interfaces",
        page_name = "interfaces",
        label = "Interfaces",
    },
    {
        active = page == "network",
        page_name = "network",
        label = "Local Networks",
    },
    {
        active = page == "snmp_device",
        page_name = "snmp_device",
        label = "SNMP Devices",
    },
    {
        active = page == "flows",
        page_name = "flows",
        label = "Flows",
    },
    {
        active = page == "system",
        page_name = "system",
        label = "System",
    },
    {
        active = page == "syslog",
        page_name = "syslog",
        label = "Syslog",
    },
})

local context = {
    template_utils = template_utils,
    json = json,
    ui_utils = ui_utils,
    alert_stats = {
        entity = page
    }
}

template_utils.render("pages/alert_stats.template", context)

-- append the menu down below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
