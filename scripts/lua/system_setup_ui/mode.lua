--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local system_setup_ui_utils = require "system_setup_ui_utils"
require "lua_utils"
require "prefs_utils"

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

system_setup_ui_utils.process_apply_discard_config(sys_config)

if table.len(_POST) > 0 then
   if not isEmptyString(_POST["operating_mode"]) then
      sys_config:setOperatingMode(_POST["operating_mode"])
      sys_config:save()
   end
end

local print_page_body = function()
  printPageSection(i18n("nedge.setup_mode"))

  local available_modes = sys_config:getAvailableModes()

  local all_modes_labels = {
    --i18n("nedge.single_port_router"),
    i18n("nedge.router"),
    i18n("bridge"),
  }

  local all_modes_values = {
    --"single_port_router",
    "routing",
    "bridging",
  }

  local modes_labels = {}
  local modes_values = {}

--tprint(available_modes)

  for idx, mode in pairs(all_modes_values) do
    if available_modes[mode] then
      modes_labels[#modes_labels + 1] = all_modes_labels[idx]
      modes_values[#modes_values + 1] = mode
    end
  end

  local current_mode = sys_config:getOperatingMode()

  local elementToSwitch = nil
  local showElementArray = nil
  local javascriptAfterSwitch = nil
  local showElement = nil
  local bridge_only = (not ntop.isnEdgeEnterprise())

  multipleTableButtonPrefs(i18n("nedge.setup_mode"),
			   i18n("nedge.set_the_device_mode"),
			   modes_labels, modes_values,
			   "",
			   "primary",
			   "operating_mode",
			   "", bridge_only,
			   elementToSwitch, showElementArray, javascriptAfterSwitch, showElement, current_mode)

  if is_nedge and bridge_only then
    prefsInformativeField("", i18n("nedge.router_mode_requires_enterprise"), true)
  end

  printSaveButton()
end

system_setup_ui_utils.print_setup_page(print_page_body, sys_config)

