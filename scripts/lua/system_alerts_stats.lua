--
-- (C) 2013-20 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path

require "lua_utils"
local snmp_utils = require "snmp_utils"
local snmp_dev = require "snmp_dev"
local json = require "dkjson"
local snmp_config = require "snmp_config"
local alert_utils = require "alert_utils"
local template = require "template_utils"
local page_utils = require("page_utils")
local plugins_utils = require("plugins_utils")
local alert_consts = require("alert_consts")
local ipv4_utils = require "ipv4_utils"
local tracker = require "tracker"
local snmp_device_pools = require "snmp_device_pools"

if not isAllowedSystemInterface() then return end

local showDevices = true
local page = _GET["page"]
local action = _POST["snmp_action"]

sendHTTPContentTypeHeader('text/html')

if not haveAdminPrivileges() then
    dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
    return
end

page_utils.set_active_menu_entry(page_utils.menu_entries.snmp)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- ########################################################################################

function del_snmp_device(snmp_device_ip)
    snmp_config.remove_device(snmp_device_ip)

    -- TRACKER HOOK
    tracker.log("del_snmp_device", {snmp_device_ip})

    return true
end

-- ########################################################################################

-- MENU
local url = ntop.getHttpPrefix() .. "/lua/system_alerts_stats.lua?ifid=" .. getSystemInterfaceId()
local title = i18n("system_alerts_status")

page_utils.print_navbar(title, url, {
    {
        active = page == "overview" or not page,
        page_name = "overview",
        label = "<i class=\"fas fa-lg fa-home\"></i>"
    },
})

-- DEVICES LIST

if page == "overview" or page == nil then
   local snmp_pools = snmp_device_pools:create()
   -- Create a filter list to use inside the overview page
   -- to filter the datatable
   local pool_filters = {}
   local all_snmp_pools = snmp_pools:get_all_pools()
   for key, value in pairs(all_snmp_pools) do
      pool_filters[#pool_filters + 1] = {
	 key = "pool-" .. key,
	 label = value.name,
	 regex = value.name,
	 countable = true
      }
   end

   local context = {
      template_utils = template,
      json = json,
      overview = {
	 buttonsVisbility = {
	    deleteAllDevices = (table.len(
				   snmp_config.get_all_configured_devices()) > 0),
	    pruneDevices = snmp_config.has_unresponsive_devices()
	 },
	 responsivenessFilters = {
	    {
	       key = "responsiveness_responsive",
	       label = i18n("snmp.responsiveness_responsive"),
	       regex = "OK",
	       countable = false
	    }, {
	       key = "responsiveness_unresponsive",
	       label = i18n("snmp.responsiveness_unresponsive"),
	       regex = "unreachable",
	       countable = false
	       }
	 },
	 poolFilters = pool_filters,
	 pools = snmp_pools,
	 all_snmp_pools = all_snmp_pools,
      }
   }

   print(template.gen('pages/system_alerts_stats.template', context))
end -- if page

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
