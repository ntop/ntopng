--
-- (C) 2019-21 - ntop.org
--

local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")
local alerts_api = require("alerts_api")

-- This is a user script executed by scripts/callbacks/system/system.lua .
-- Changes to this script must be applied by reloading the plugins from
-- http://127.0.0.1:3000/lua/plugins_overview.lua

local global_state = nil

-- #################################################################

local script = {
  -- Script category, see checks.check_categories for all available categories
  category = checks.check_categories.other,

  -- This module is enabled by default
  default_enabled = true,

  -- The default configuration for this plugin. The current configuration
  -- is passed to the script hooks as the second parameter.
  default_value = {
    -- This configuration is specific of this script
    ip_address = "8.8.8.8",
    v6 = false,
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
    i18n_title = "example.interface_script_title",

    -- A description for this user script
    i18n_description = "example.interface_script_description",
  },

  ----------------------------------------------------------------------

  -- If true, the script will be automatically disabled when alerts are
  -- disabled.

  -- If true, this script will only be executed on packet interfaces
  packet_interface_only = false,

  -- If true, this script will only be executed in nEdge
  nedge_only = false,

  -- If true, this script will not be executed in nEdge
  nedge_exclude = false,

  -- If true, this script will not be available on Windows.
  windows_exclude = false,
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

-- An hook executed every minute.
function script.hooks.min(info)
  --tprint(info)
  print("system:min hook called")

  ntop.pingHost(info.check_config.ip_address, info.check_config.v6)

  -- Wait results
  ntop.msleep(2000)

  local res = ntop.collectPingResults()

  -- The alert entity must be built manually for system scripts
  local alert_entity = {
    alert_entity = alert_consts.alert_entities.am_host,
    alert_entity_val = info.check_config.ip_address,
  }

  local alert_info = {
    alert_type = alert_consts.alert_types.alert_example,
    alert_severity = alert_severities.notice,
    alert_granularity = info.granularity,
    alert_type_params = {},
  }

  if(res[info.check_config.ip_address] ~= nil) then
    print(string.format("Host %s is active", info.check_config.ip_address))

    -- Release previously triggered alert (if any)
    alerts_api.release(alert_entity, alert_info)
  else
    print(string.format("Host %s is down", info.check_config.ip_address))

    -- Trigger alert
    alerts_api.trigger(alert_entity, alert_info)
  end
end

-- #################################################################

-- An hook executed every 5 minutes.
script.hooks["5mins"] = function(info)
  print("system:5mins hook called")
end

-- #################################################################

-- An hook executed every hour.
function script.hooks.hour(info)
  print("system:hour hook called")
end

-- #################################################################

-- An hook executed every day.
function script.hooks.day(info)
  print("system:day hook called")
end

-- #################################################################

return script
