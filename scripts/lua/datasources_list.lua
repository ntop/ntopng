--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local datasources_utils = require("datasources_utils")
local ts_utils = require("ts_utils")
local info = ntop.getInfo()
local page_utils = require("page_utils")
local format_utils = require("format_utils")
local template = require "template_utils"
local json = require "dkjson"

local function ends_with(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.datasources_list)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
page_utils.print_page_title("Datasources")

-- List available datasources
local dss = ntop.readdir(dirs.installdir .. "/scripts/lua/datasources")

-- Cleanup results and allow only .lua filea
for k,v in pairs(dss) do
   if(not(ends_with(k, ".lua"))) then
      dss[k] = nil
   end
end

-- Prepare the response

local context = {
   datasources_list = {
      datasources = dss
    },
    template_utils = template,
    page_utils = page_utils,
    info = ntop.getInfo(),
}

-- print config_list.html template
print(template.gen("pages/datasource_list.template", context))

-- append the menu below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
