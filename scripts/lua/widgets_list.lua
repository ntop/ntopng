--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local widgets_utils = require("widget_utils")
local datasources_utils = require("datasources_utils")
local ts_utils = require("ts_utils")
local info = ntop.getInfo()
local page_utils = require("page_utils")
local format_utils = require("format_utils")
local template = require "template_utils"
local json = require "dkjson"

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.widgets_list)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
page_utils.print_page_title("Widgets")

-- Get all interface names and ids
local iface_names = interface.getIfNames()
local interfaces_list = {}

-- Add default whenever no interface has to be selected
interfaces_list[-1] = "None"

for v, k in pairs(iface_names) do

    interface.select(k)
    local _ifstats = interface.getStats()
    interfaces_list[_ifstats.id] = getHumanReadableInterfaceName(_ifstats.description .. "")
end

local context = {
    widgets_list = {
        datasources = datasources_utils.get_all_sources(),
        widgets_type = widgets_utils.get_widget_types(),
        interfaces = interfaces_list
    },
    template_utils = template,
    page_utils = page_utils,
    info = ntop.getInfo(),
}

-- print config_list.html template
print(template.gen("pages/widgets_list.template", context))

-- append the menu below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
