--
-- (C) 2020 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local page_utils = require "page_utils"
local json = require "dkjson"
local template_utils = require "template_utils"
local host_pools = require "host_pools"
local interface_pools = require "interface_pools"
local local_network_pools = require "local_network_pools"
local active_monitoring_pools = require "active_monitoring_pools"
local notification_recipients = require "notification_recipients"
local snmp_device_pools

local page = _GET["page"] or "host"
-- load the snmp module only in the pro version
if ntop.isPro() then
   snmp_device_pools = require "snmp_device_pools"
end

sendHTTPContentTypeHeader('text/html')

if not haveAdminPrivileges() then return end
page_utils.set_active_menu_entry(page_utils.menu_entries.manage_pools)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- if the selected page is snmp but we aren't in pro version
-- then block the user with an alert
if page == "snmp" and not ntop.isPro() then
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
   return
end


page_utils.print_page_title(i18n("pools.pools"))

-- ************************************* ------

local pool_type
local pool_instance

if page == "interface" then
   pool_instance = interface_pools:create()
elseif page == "network" then
   pool_instance = local_network_pools:create()
elseif page == "active_monitoring" then
   pool_instance = active_monitoring_pools:create()
elseif page == "snmp" then
   pool_instance = snmp_device_pools:create()
else
   pool_instance = host_pools:create()
end

if page == "snmp" then
   pool_type = "snmp/device"
else
   pool_type = page
end

local menu = {
   entries = {
      host = { title = i18n("pools.pool_names.host"), url = "?page=host", hidden = false},
      interface = { title = i18n("pools.pool_names.interface"), url = "?page=interface", hidden = false},
      network = { title = i18n("pools.pool_names.local_network"), url = "?page=network", hidden = false},
      active_monitoring = { title = i18n("pools.pool_names.active_monitoring"), url = "?page=active_monitoring", hidden = false },
      snmp = { title = i18n("pools.pool_names.snmp"), url = "?page=snmp", hidden = (not ntop.isPro())},
   },
   current_page = page
}

local context = {
    template_utils = template_utils,
    json = json,
    menu = menu,
    pool = {
        name = page,
        instance = pool_instance,
        all_members = pool_instance:get_all_members(),
        configsets = pool_instance:get_available_configset_ids(),
        assigned_members = pool_instance:get_assigned_members(),
        endpoints = {
            get_all_pools  = string.format("/lua/rest/v1/get/%s/pools.lua", pool_type),
            add_pool       = string.format("/lua/rest/v1/add/%s/pool.lua", pool_type),
            edit_pool      = string.format("/lua/rest/v1/edit/%s/pool.lua", pool_type),
            delete_pool    = string.format("/lua/rest/v1/delete/%s/pool.lua", pool_type),
        },
        notification_recipients = notification_recipients
    }
}

print(template_utils.gen("pages/table_pools.template", context))

-- ************************************* ------

-- append the menu below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")