--
-- (C) 2019-20 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/toasts/?.lua;" .. package.path

require "lua_utils"

local page_utils = require("page_utils")
local ui_utils = require("ui_utils")
local template = require "template_utils"
local json = require "dkjson"
local plugins_utils = require("plugins_utils")
local toasts_manager = require("toasts_manager")
local user_scripts = require("user_scripts")
local alert_consts = require("alert_consts")
local notification_configs = require("notification_configs")
local endpoints = notification_configs.get_configs(true)

if not haveAdminPrivileges() then
    return
end

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.endpoint_recipients)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
-- print a notification container used by the AJAX operations
toasts_manager.render_toasts('recipients', {})

local url = ntop.getHttpPrefix() .. "/lua/admin/recipients_list.lua"
page_utils.print_navbar(i18n("endpoint_notifications.recipient_list"), url, {
    {
        active = true,
        page_name = "home",
        label = "<i class=\"fas fa-lg fa-home\"></i>",
        url = url
    }
})

-- localize endpoint name types in a table
local endpoints_types = notification_configs.get_types()
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

local can_create_recipient = not table.all(endpoints,
    function(endpoint)
        return (endpoint.builtin ~= nil)
    end
)

local context = {
    notifications = {
        endpoints = endpoints_types,
        endpoint_types_labels = endpoint_types_labels,
        endpoint_list = endpoints,
        can_create_recipient = can_create_recipient,
        script_categories = user_scripts.script_categories,
        alert_severities = alert_consts.alert_severities,
        filters = {
            endpoint_types = endpoint_type_filters
        }
    },
    plugins_utils = plugins_utils,
    ui_utils = ui_utils,
    template_utils = template,
    page_utils = page_utils,
    json = json,
    info = ntop.getInfo()
}

-- print config_list.html template
print(template.gen("pages/recipients_list.template", context))

-- append the menu below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
