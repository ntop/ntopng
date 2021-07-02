--
-- (C) 2019-21 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require("page_utils")
local ui_utils = require("ui_utils")
local template = require "template_utils"
local json = require "dkjson"
local plugins_utils = require("plugins_utils")
local endpoints = require("endpoints")

sendHTTPContentTypeHeader('text/html')

if not isAdministratorOrPrintErr() then
    return
end

local function get_max_configs_available()
    local availables = {}
    local types = endpoints.get_types(true --[[ exclude builtin --]])

    for endpoint_key, endpoint in pairsByKeys(types, asc) do
        local conf_max_num = endpoint.conf_max_num

        if conf_max_num ~= nil then
            availables[endpoint_key] = conf_max_num
        else
            availables[endpoint_key] = -1
        end
    end

    return availables
end


page_utils.set_active_menu_entry(page_utils.menu_entries.endpoint_notifications)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local url = ntop.getHttpPrefix() .. "/lua/admin/endpoint_notifications_list.lua"
page_utils.print_navbar(i18n("endpoint_notifications.endpoint_list"), url, {
    {
        active = true,
        page_name = "home",
        label = "<i class=\"fas fa-lg fa-home\"></i>",
        url = url
    }
})


-- localize endpoint name types in a table
local endpoints_types = endpoints.get_types(false)
local endpoint_types_labels = {}
-- create a table to filter recipient by endpoint's type
local endpoint_type_filters = {}
for endpoint_key, endpoint in pairs(endpoints_types) do

    local label = endpoint.name
    endpoint_types_labels[endpoint_key] = label

    endpoint_type_filters[#endpoint_type_filters+1] = {
        label = label,
        regex = endpoint_key,
        key = endpoint_key,
        countable = true
    }

end

-- Prepare the response
local context = {
    notifications = {
        endpoints = endpoints.get_types(true --[[ exclude builtin --]]),
        endpoints_info = get_max_configs_available(),
        endpoint_types_labels = endpoint_types_labels,
        filters = {
            endpoint_types = endpoint_type_filters
        }
    },
    ui_utils = ui_utils,
    template_utils = template,
    plugins_utils = plugins_utils,
    page_utils = page_utils,
    json = json,
    info = ntop.getInfo()
}

-- print config_list.html template
print(template.gen("pages/endpoint_notifications_list.template", context))

-- append the menu below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
