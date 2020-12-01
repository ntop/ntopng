--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local system_setup_ui_utils = require "system_setup_ui_utils"
local template = require "template_utils"
require "prefs_utils"
require "lua_utils"
prefsSkipRedis(true)

local is_appliance = ntop.isAppliance()
local is_iot_bridge = ntop.isIoTBridge()

if not (is_appliance and is_iot_bridge) or not isAdministrator() then
   return
end

local sys_config
package.path = dirs.installdir .. "/scripts/lua/modules/system_config/?.lua;" .. package.path
sys_config = require("appliance_config"):create(true)

local operating_mode = sys_config:getOperatingMode()
system_setup_ui_utils.process_apply_discard_config(sys_config)

if _POST["wifi_enabled"] ~= nil then
  local wifi_config = sys_config:getWirelessConfiguration()
 
  if _POST["wifi_enabled"]  ~= nil then wifi_config.enabled = ternary(_POST["wifi_enabled"] == "1", true, false) end
  if _POST["wifi_ssid"] ~= nil then wifi_config.ssid = _POST["wifi_ssid"] end
  if _POST["wpa_passphrase"] ~= nil then wifi_config.passphrase = _POST["wpa_passphrase"] end

  sys_config:setWirelessConfiguration(wifi_config)
  sys_config:save()
end

local function print_wifi_page_body()
  local wifi_config = sys_config:getWirelessConfiguration()

tprint(wifi_config)

  printPageSection("<span id='wifi_interface'>" .. i18n("prefs.wifi")  .. "</span>")

  local elementToSwitch = { "wifi_ssid", "wpa_passphrase" }

  prefsToggleButton(subpage_active, {
    title = i18n("appliance.enable_wifi"),
    description = i18n("appliance.enable_wifi_descr"),
    content = "",
    field = "wifi_enabled",
    pref = "",
    redis_prefix = "",
    default = ternary(wifi_config.enabled, "1", "0"),
    to_switch = elementToSwitch,
  })

  prefsInputFieldPrefs(
    i18n("appliance.ssid"),
    i18n("appliance.ssid_descr"),
    "",
    "wifi_ssid",
    wifi_config.ssid or "ntopng",
    nil,
    wifi_config.enabled,
    nil,
    nil,
    {
      required = true
    }
  )

  prefsInputFieldPrefs(
    i18n("appliance.wpa_passphrase"),
    i18n("appliance.wpa_passphrase_descr"),
    "",
    "wpa_passphrase",
    wifi_config.passphrase or "",
    "password",
    wifi_config.enabled,
    nil,
    nil,
    {
      required = false
    }
  )

  printSaveButton()
end

system_setup_ui_utils.print_setup_page(print_wifi_page_body, sys_config)

