--
-- (C) 2020 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path


require "lua_utils"
local page_utils = require "page_utils"
local ui_utils = require "ui_utils"
local json = require "dkjson"
local template_utils = require "template_utils"
local endpoints = require("endpoints")
local alert_entities = require "alert_entities"

local host_pools              = require "host_pools"
local flow_pools              = require "flow_pools"
local system_pools            = require "system_pools"
local device_pools            = require "mac_pools"
local interface_pools         = require "interface_pools"
local host_pool_pools         = require "host_pool_pools"
local local_network_pools     = require "local_network_pools"
local active_monitoring_pools = require "active_monitoring_pools"

-- ****** SNMP Pool ******
local snmp_device_pools

-- load the snmp module only in the pro version
if ntop.isPro() then
   snmp_device_pools = require "snmp_device_pools"
end

-- ************************

local recipients = require "recipients"

-- *************** end of requires ***************

local is_nedge = ntop.isnEdge()

-- select the default page
local page = _GET["page"] or 'host'

sendHTTPContentTypeHeader('text/html')

if not isAdministratorOrPrintErr() then return end

page_utils.set_active_menu_entry(page_utils.menu_entries.manage_pools)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- if the selected page is snmp but we aren't in pro version
-- then block the user with an alert
if page == "snmp" and not ntop.isPro() then
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
   return
end

local url = ntop.getHttpPrefix() .. "/lua/admin/manage_pools.lua"
page_utils.print_navbar(i18n("pools.pools"), url, {
    {
        active = true,
        page_name = "home",
        label = "<i class=\"fas fa-lg fa-home\"></i>",
        url = url
    }
})

-- ************************************* ------

local ALL_POOL_GET_ENDPOINT = '/lua/rest/v2/get/pools.lua'

local pool_types = {

   -- Normal Pools
   ["interface"] = interface_pools,
   ["local_network"] = local_network_pools,
   ["active_monitoring"] = active_monitoring_pools,
   ["snmp_device"] = snmp_device_pools,
   ["host"] = host_pools,

   -- Default Only Pools
   ["host_pool"] = host_pool_pools,
   ["flow"] = flow_pools,
   ["system"] = system_pools,
   ["mac"] = device_pools
}

local pool_instance = (page ~= 'all' and pool_types[page]:create() or {})
local pool_type = page

if pool_type == 'snmp_device' then
   pool_type = "snmp/device"
elseif pool_type == 'local_network' then
   pool_type = 'network'
end

local menu = {
   entries = {

      -- Normal Pools
      { key = "host", title = i18n(alert_entities.host.i18n_label), url = "?page=host", hidden = false},
      { key = "interface", title = i18n(alert_entities.interface.i18n_label), url = "?page=interface", hidden = false},
      { key = "local_network", title = i18n(alert_entities.network.i18n_label), url = "?page=local_network", hidden = false},
      { key = "snmp_device", title = i18n(alert_entities.snmp_device.i18n_label), url = "?page=snmp_device", hidden = not ntop.isPro() or is_nedge},
      { key = "active_monitoring", title = i18n(alert_entities.am_host.i18n_label), url = "?page=active_monitoring", hidden = false },

   -- Default Only Pools
      { key = "host_pool", title = i18n(alert_entities.host_pool.i18n_label), url = "?page=host_pool", hidden = false},
      { key = "flow", title = i18n(alert_entities.flow.i18n_label), url = "?page=flow", hidden = false},
      { key = "mac", title = i18n(alert_entities.mac.i18n_label), url = "?page=mac", hidden = false},
      { key = "system", title = i18n(alert_entities.system.i18n_label), url = "?page=system", hidden = false},

      -- All Pool
      { key = "all", title = i18n("pools.pool_names.all"), url = "?page=all", hidden = false},
   },
   current_page = page
}

local pool_families = {}
for _, entry in ipairs(menu.entries) do
   pool_families[entry.key] = entry.title
end

local rest_endpoints = {
   get_all_pools  = (page == "all" and ALL_POOL_GET_ENDPOINT or string.format(ntop.getHttpPrefix() .. "/lua/rest/v2/get/%s/pools.lua", pool_type)),
   add_pool       = string.format(ntop.getHttpPrefix() .. "/lua/rest/v2/add/%s/pool.lua", pool_type),
   edit_pool      = string.format(ntop.getHttpPrefix() .. "/lua/rest/v2/edit/%s/pool.lua", pool_type),
   delete_pool    = string.format(ntop.getHttpPrefix() .. "/lua/rest/v2/delete/%s/pool.lua", pool_type),
}

local context = {
    template_utils = template_utils,
    json = json,
    menu = menu,
    ui_utils = ui_utils,
    is_nedge = is_nedge,
    pool = {
        name = page,
        pool_families = pool_families,
        is_all_pool = (page == "all"),
        instance = pool_instance,
        all_members = (page ~= "all" and pool_instance:get_all_members() or {}),
        assigned_members = (page ~= "all" and pool_instance:get_assigned_members() or {}),
        endpoints = rest_endpoints,
        endpoint_types = endpoints.get_types(),
        notification_recipients = recipients.get_all_recipients()
    }
}

print(template_utils.gen("pages/table_pools.template", context))
-- ************************************* ------

-- append the menu down below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
