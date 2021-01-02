--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local system_setup_ui_utils = require "system_setup_ui_utils"
local ipv4_utils = require("ipv4_utils")
require "lua_utils"
require "prefs_utils"
prefsSkipRedis(true)

if not (ntop.isnEdge() or ntop.isAppliance()) or not isAdministrator() then
   return
end

local sys_config
if ntop.isnEdge() then
   package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/system_config/?.lua;" .. package.path
   sys_config = require("nf_config"):create(true)
else -- ntop.isAppliance()
   package.path = dirs.installdir .. "/scripts/lua/modules/system_config/?.lua;" .. package.path
   sys_config = require("appliance_config"):create(true)
end

system_setup_ui_utils.process_apply_discard_config(sys_config)

local warnings = {}

if table.len(_POST) > 0 then
   local changed = false
   local dhcp_config = sys_config:getDhcpServerConfig()

   if (_POST["dhcp_server_enabled"] ~= nil) then
      dhcp_config.enabled = ternary(_POST["dhcp_server_enabled"] == "1", true, false)
      changed = true
   end

   if (_POST["dhcp_first_ip"] ~= nil) and (_POST["dhcp_last_ip"]) then
      dhcp_config.subnet.first_ip = _POST["dhcp_first_ip"]
      dhcp_config.subnet.last_ip = _POST["dhcp_last_ip"]
      changed = true
   end

   if changed then
      sys_config:setDhcpServerConfig(dhcp_config)
      sys_config:save()
   end
end

local dhcp_config = sys_config:getDhcpServerConfig()

if not dhcp_config.enabled and sys_config:isMultipathRoutingEnabled() then
   warnings[#warnings + 1] = i18n("nedge.dhcp_disabled_warning")
end

local print_page_body = function()
   local lan_network = sys_config:getStaticLanNetwork()

   printPageSection(i18n("nedge.dhcp_server"))

   local dhcpElementsToSwitch = {"dhcp_first_ip__id", "dhcp_last_ip__id"}

   prefsToggleButton(subpage_active, {
      title = i18n("nedge.dhcp_server"),
      description = i18n("nedge.dhcp_server_description"),
      content = "",
      field = "dhcp_server_enabled",
      default = ternary(dhcp_config.enabled, "1", "0"),
      to_switch = dhcpElementsToSwitch,
      pref = "",
      redis_prefix = "",
   })

   local to_show = dhcp_config.enabled

   system_setup_ui_utils.printPrivateAddressSelector(i18n("nedge.dhcp_first_ip"), i18n("nedge.dhcp_first_ip_descr"), "dhcp_first_ip", nil, dhcp_config.subnet.first_ip, to_show, {
      net_select = false,
      quad3_select = ternary(lan_network.netmask == "255.255.255.0", false, nil),
   })

   system_setup_ui_utils.printPrivateAddressSelector(i18n("nedge.dhcp_last_ip"), i18n("nedge.dhcp_last_ip_descr"), "dhcp_last_ip", nil, dhcp_config.subnet.last_ip, to_show, {
      net_select = false,
      quad3_select = ternary(lan_network.netmask == "255.255.255.0", false, nil),
   })

   local msg = ternary(dhcp_config.enabled, [[<div class="float-left">]] .. i18n("nedge.you_can_set_static_dhcp_lease_here", {url=ntop.getHttpPrefix().."/lua/pro/nedge/admin/dhcp_leases.lua"}, "") .. [[</div>]])

   printSaveButton(msg)
end

system_setup_ui_utils.print_setup_page(print_page_body, sys_config, warnings)

