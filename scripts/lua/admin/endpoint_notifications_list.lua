--
-- (C) 2019-20 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require("page_utils")
local template = require "template_utils"
local json = require "dkjson"
local plugins_utils = require("plugins_utils")
local notification_configs = require("notification_configs")

sendHTTPContentTypeHeader('text/html')

if not haveAdminPrivileges() then
    return
end

local function get_max_configs_available()

    local availables = {}
    local types = notification_configs.get_types()

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
page_utils.print_page_title(i18n("endpoint_notifications.endpoint_list"))

-- Prepare the response
local context = {
    notifications = {
        endpoints = notification_configs.get_types(),
        endpoints_info = get_max_configs_available()
    },
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
