--
-- (C) 2019-22 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require("page_utils")
local ui_utils = require("ui_utils")
local template_utils = require "template_utils"
local json = require "dkjson"
local script_manager = require("script_manager")
local endpoints = require("endpoints")
local checks = require("checks")
local alert_severities = require "alert_severities"
local alert_entities = require "alert_entities"
local am_utils = require "am_utils"
local host_pools = require "host_pools":create()

sendHTTPContentTypeHeader('text/html')

local NOTIFICATION_URL = "/lua/admin/endpoint_notifications_list.lua"
local check_subdir = _GET["subdir"] or "endpoint"

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

local sub_menu_entries = {
  ['endpoint'] = {
     order = 0,
     entry = page_utils.menu_entries.endpoint_notifications
  },
  ['recipient'] = {
     order = 1,
     entry = page_utils.menu_entries.endpoint_recipients
  },
}

local active_entry = sub_menu_entries[check_subdir].entry or page_utils.menu_entries.endpoint_notifications
local navbar_menu = {}

page_utils.set_active_menu_entry(active_entry)

for key, sub_menu in pairsByField(sub_menu_entries, 'order', asc) do
  navbar_menu[#navbar_menu+1] = {
    active = (check_subdir == key),
    page_name = key,
    label = i18n(sub_menu.entry.i18n_title),
    url = NOTIFICATION_URL .. "?subdir=" .. key
  }
end


-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local url = ntop.getHttpPrefix() .. "/lua/admin/endpoint_notifications_list.lua"
page_utils.print_navbar(i18n("endpoint_notifications.notifications"), '#', navbar_menu)

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

local endpoint_list = endpoints.get_types(true --[[ exclude builtin --]])

local can_create_recipient = not table.all(endpoint_list,
    function(endpoint)
        return (endpoint.builtin ~= nil)
    end
)

local am_hosts = am_utils.getHosts()
local am_hosts_list = {}

for key, am_host in pairs(am_hosts) do
   local label = am_host.label
   local m_info = am_utils.getMeasurementInfo(am_host.measurement)
   if m_info then
      label = label .. ' · ' .. i18n(m_info.i18n_label)
   end

   am_hosts_list[#am_hosts_list+1] = {
      id = key,
      name = label,
   }
end

-- Prepare the response
local context = {
  notifications = {
    endpoint_types_labels = endpoint_types_labels,
    endpoint_template = endpoints,
    endpoint_list = endpoints.get_configs(true),
    can_create_recipient = can_create_recipient,
    check_categories = checks.check_categories,
    check_entities = alert_entities,
    alert_severities = alert_severities,
    endpoints = endpoint_list,
    endpoints_info = get_max_configs_available(),
    am_hosts = am_hosts_list,
    filters = {
        endpoint_types = endpoint_type_filters
    },
    pools = {
        host_pools = host_pools:get_all_pools(),
    },
  },
  ui_utils = ui_utils,
  template_utils = template_utils,
  script_manager = script_manager,
  page_utils = page_utils,
  json = json,
  info = ntop.getInfo()
}

-- print config_list.html template
if check_subdir == "endpoint" then
  template_utils.render("pages/endpoint_notifications_list.template", context)
else
  template_utils.render("pages/recipients_list.template", context)
end

-- append the menu below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
