--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/system_config/?.lua;" .. package.path

local system_setup_ui_utils = require "system_setup_ui_utils"
require "lua_utils"
require "prefs_utils"

local nf_config = require("nf_config"):create(true)

system_setup_ui_utils.process_apply_discard_config(nf_config)

if table.len(_POST) > 0 then
   if not isEmptyString(_POST["operating_mode"]) then
      nf_config:setOperatingMode(_POST["operating_mode"])
     nf_config:save()
   end
end

local print_page_body = function()
  printPageSection(i18n("nedge.setup_mode"))

  local available_modes = nf_config:getAvailableModes()

  local all_l7_rrd_labels = {
    --i18n("nedge.single_port_router"),
    i18n("nedge.router"),
    i18n("bridge"),
  }

  local all_l7_rrd_values = {
    --"single_port_router",
    "routing",
    "bridging",
  }

  local l7_rrd_labels = {}
  local l7_rrd_values = {}

  for idx, mode in pairs(all_l7_rrd_values) do
    if available_modes[mode] then
      l7_rrd_labels[#l7_rrd_labels + 1] = all_l7_rrd_labels[idx]
      l7_rrd_values[#l7_rrd_values + 1] = mode
    end
  end

  local current_mode = nf_config:getOperatingMode()

  local elementToSwitch = nil
  local showElementArray = nil
  local javascriptAfterSwitch = nil
  local showElement = nil
  local bridge_only = (not ntop.isnEdgeEnterprise())

  multipleTableButtonPrefs(i18n("nedge.setup_mode"),
				    i18n("nedge.set_the_device_mode"),
				    l7_rrd_labels, l7_rrd_values,
				    "",
				    "primary",
				    "operating_mode",
				    "", bridge_only,
				    elementToSwitch, showElementArray, javascriptAfterSwitch, showElement, current_mode)

  if bridge_only then
    prefsInformativeField("", i18n("nedge.router_mode_requires_enterprise"), true)
  end

  printSaveButton()
end

system_setup_ui_utils.print_setup_page(print_page_body, nf_config)

