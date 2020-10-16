--
-- (C) 2019-20 - ntop.org
--

local alert_consts = require("alert_consts")
local alerts_api = require("alerts_api")
local snmp_utils = require "snmp_utils"

-- This is a user script executed by scripts/callbacks/system/snmp_device.lua .
-- The SNMP devices must be already configured from the System -> SNMP page.
-- Changes to this script must be applied by reloading the plugins from
-- http://127.0.0.1:3000/lua/plugins_overview.lua

local global_state = nil

-- #################################################################

local script = {
  -- Script category, see user_scripts.script_categories for all available categories
  category = user_scripts.script_categories.other,

  -- This module is enabled by default
  default_enabled = true,

  -- The default configuration for this plugin. The current configuration
  -- is passed to the script hooks as the second parameter.
  default_value = {
    -- This configuration is specific of this script
    some_setting = "my custom config value",
  },

  -- A user script must be attached some hooks in order to be executed.
  -- This is only a placeholder, see below for the hooks definitions.
  -- NOTE: the "all" hook is a virtual hook which causes the script to
  -- be attached to all the available hooks.
  hooks = {},

  -- GUI specific stuff. If this section is missing, the user script
  -- will not be shown in the gui.
  gui = {
    -- A title for this user script
    i18n_title = "example.snmp_script_title",

    -- A description for this user script
    i18n_description = "example.snmp_script_description",
  },

  ----------------------------------------------------------------------

  -- If true, the script will be automatically disabled when alerts are
  -- disabled.
  is_alert = false,

  -- If true, this script will only be executed on packet interfaces
  packet_interface_only = false,

  -- If true, this script will only be executed in nEdge
  nedge_only = false,

  -- If true, this script will not be executed in nEdge
  nedge_exclude = false,

  -- If true, this script will not be available on Windows.
  windows_exclude = false,

  ----------------------------------------------------------------------

  -- Skip virtual interfaces (e.g. loopback) in the "snmpDeviceInterface" hook
  skip_virtual_interfaces = true,
}

-- #################################################################

-- @brief Called when the script is going to be loaded.
-- @return true if the script should be loaded, false otherwise
-- @notes Can be used to init some script global state or to skip the script
-- execution on some particular conditions
function script.setup()
  local is_enabled = true -- your custom condition here

  global_state = {}

  return(is_enabled)
end

-- #################################################################

-- An hook executed at every poll of the SNMP device.
-- @param device_ip the SNMP device IP address
-- @param info information about the device and its interfaces.
function script.hooks.snmpDevice(device_ip, info)
  --tprint(info)
  print("SNMP:snmpDevice hook called: " .. device_ip)

  local alert_info = {
     alert_type = alert_consts.alert_types.alert_example,
     alert_severity = alert_consts.alert_severities.notice,
     alert_granularity = info.granularity,
     alert_type_params = {
	device = device_ip,
     },
  }

  if isSNMPDeviceUnresponsive(device_ip) then
    -- Trigger alert
    alerts_api.trigger(info.alert_entity, alert_info)
  else
    -- Release previously triggered alert
    alerts_api.release(info.alert_entity, alert_info)
  end
end

-- #################################################################

-- An hook executed at every poll of the SNMP device, for each interface.
-- @param device_ip the SNMP device IP address
-- @param if_index numeric index of the interface
-- @param info information about the interface
-- @notes Check out skip_virtual_interfaces
function script.hooks.snmpDeviceInterface(device_ip, if_index, info)
  --tprint(info)
  print("SNMP:snmpDeviceInterface hook called: " .. device_ip .. "@" .. if_index)

  alerts_api.store(info.alert_entity, {
     alert_type = alert_consts.alert_types.alert_example,
     alert_severity = alert_consts.alert_severities.warning,
     alert_type_params = {
	device = device_ip,
	interface = if_index,
	interface_name = info["name"],
     },
  })
end

-- #################################################################

return script
