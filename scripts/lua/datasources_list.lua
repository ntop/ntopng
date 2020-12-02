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

local url = ntop.getHttpPrefix() .. "/lua/datasources_list.lua"
page_utils.print_navbar(i18n("developer_section.datasources_list"), url, {
    {
        active = true,
        page_name = "home",
        label = "<i class=\"fas fa-lg fa-home\"></i>",
        url = url
    }
})

-- List available datasources
local dss = ntop.readdir(dirs.installdir .. "/scripts/lua/datasources")

-- Cleanup results and allow only .lua filea
for k, v in pairs(dss) do if (not (ends_with(k, ".lua"))) then dss[k] = nil end end

-- All the family schemas
local schemas = ts_utils.getLoadedSchemas()
local families = {}

for k, v in pairs(schemas) do
    if (type(v) == "table") then

        local s = split(k, ":")

        if ((s ~= nil) and (s[1] ~= nil)) then

            local tags = {}
            local metrics = {}

            if (families[s[1]] == nil) then families[s[1]] = {} end

            for t, _ in pairs(v.tags) do table.insert(tags, t) end
            for m, _ in pairs(v.metrics) do table.insert(metrics, m) end

            if (#metrics > 0) then
                families[s[1]][k] = {}
                families[s[1]][k]['tags'] = tags
                families[s[1]][k]['metrics'] = metrics
            end
        end
    end
end

-- Prepare the response

local context = {
    datasources_list = {datasources = dss, timeseries = families},
    template_utils = template,
    page_utils = page_utils,
    json = json,
    info = ntop.getInfo(),
    csrf = ntop.getRandomCSRFValue(),
}

-- print config_list.html template
print(template.gen("pages/datasource_list.template", context))

-- append the menu below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
