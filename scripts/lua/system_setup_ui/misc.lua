--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local template = require "template_utils"
local system_setup_ui_utils = require "system_setup_ui_utils"
require "lua_utils"
require "prefs_utils"
prefsSkipRedis(true)

local is_nedge = ntop.isnEdge()
local is_appliance = ntop.isAppliance()

if not (is_nedge or is_appliance) or not isAdministrator() then
   return
end

local sys_config
if is_nedge then
   package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/system_config/?.lua;" .. package.path
   sys_config = require("nf_config"):create(true)
else -- ntop.isAppliance()
   package.path = dirs.installdir .. "/scripts/lua/modules/system_config/?.lua;" .. package.path
   sys_config = require("appliance_config"):create(true)
end

local info = ntop.getInfo(false)

system_setup_ui_utils.process_apply_discard_config(sys_config)

if table.len(_POST) > 0 then
  if (_POST["factory_reset"] ~= nil) then
    sys_config:prepareFactoryReset()
  elseif (_POST["data_reset"] ~= nil) then
    sys_config:prepareDataReset()
  else
    local changed = false

    if (_POST["lan_recovery_ip"] ~= nil) and (_POST["lan_recovery_netmask"] ~= nil) then
      local lan_recovery = sys_config:getLanRecoveryIpConfig()
      lan_recovery.ip = _POST["lan_recovery_ip"]
      lan_recovery.netmask = _POST["lan_recovery_netmask"]
      sys_config:setLanRecoveryIpConfig(lan_recovery)
      changed = true
    end

    if changed then
      sys_config:save()
    end
  end
end

local function print_page_body()
  printPageSection(i18n("prefs.network_interfaces"))
  local lan_recovery = sys_config:getLanRecoveryIpConfig()
  local descr = i18n("nedge.lan_recovery_ip_descr", {product=info["product"]}) .. "<br><b>" .. i18n("nedge.lan_recovery_warning") .. "</b>"
  system_setup_ui_utils.printPrivateAddressSelector(i18n("nedge.lan_recovery_ip"), descr, "lan_recovery_ip", "lan_recovery_netmask", lan_recovery.ip, true)

  print('<tr><th colspan=2 style="text-align:right;">')
  if is_nedge then
    print('<button class="btn btn-danger disable-on-dirty" type="button" onclick="$(\'#factoryResetDialog\').modal(\'show\');" style="width:200px; float:left;">'..i18n("nedge.factory_reset")..'</button>')
    print('<button class="btn btn-danger disable-on-dirty" type="button" onclick="$(\'#dataResetDialog\').modal(\'show\');" style="width:200px; float:left; margin-left:10px;"> '..i18n("nedge.data_reset")..'</button>')
  end
  print('<button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button>')
  print('</th></tr>')
end

if not system_setup_ui_utils.print_page_before() then
  return
end

if is_nedge then

  print(
   template.gen("modal_confirm_dialog.html", {
		   dialog={
		      id      = "factoryResetDialog",
		      action  = "$('#factoryResetForm').submit()",
		      title   = i18n("nedge.factory_reset"),
		      message = i18n("nedge.factory_reset_msg"),
		      confirm = i18n("nedge.reset_and_reboot"),
		      confirm_button = "btn-danger",
		   }
   })
  )

  print(
   template.gen("modal_confirm_dialog.html", {
		   dialog = {
		      id      = "dataResetDialog",
		      action  = "$('#dataResetForm').submit()",
		      title   = i18n("nedge.data_reset"),
		      message = i18n("nedge.data_reset_msg", {product = ntop.getInfo()["product"]}),
		      confirm = i18n("nedge.reset_and_restart_self"),
		      confirm_button = "btn-danger",
		   }
   })
  )

  print[[
  <form id="factoryResetForm" method="POST">
    <input name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" type="hidden" />
    <input name="factory_reset" value="" type="hidden" />
  </form>
  ]]

  print[[
  <form id="dataResetForm" method="POST">
    <input name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" type="hidden" />
    <input name="data_reset" value="" type="hidden" />
  </form>
  ]]

end

system_setup_ui_utils.print_page_after(print_page_body, sys_config, {})
