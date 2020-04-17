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
page_utils.print_page_title("Widgets Test")

local context = {
    widgets_test = {
    },
    template_utils = template,
    page_utils = page_utils,
    info = ntop.getInfo(),
}

print(template.gen("pages/widgets_test.template", context))

-- append the menu below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
