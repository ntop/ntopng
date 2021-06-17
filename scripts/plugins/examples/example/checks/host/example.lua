--
-- (C) 2019-21 - ntop.org
--

local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")
local alerts_api = require("alerts_api")

-- This is a user script executed by scripts/callbacks/interface/host.lua .
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
    some_setting = "my custom config value",
    max_bytes = 128,
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
    i18n_title = "example.host_script_title",

    -- A description for this user script
    i18n_description = "example.host_script_description",
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

  ----------------------------------------------------------------------

  -- If true, the script will only be executed on local hosts
  -- https://www.ntop.org/guides/ntopng/basic_concepts/hosts.html#local-hosts
  local_only = false,
}

-- #################################################################

-- @brief Called, for every enabled hook, upon ntopng startup or upon plugins reload at runtime
-- @param hook The name of the enabled hook (e.g., min, hour)
-- @param hook_config A Lua table with the hook configuration
-- @return nil
function script.onLoad(hook, hook_config)
   tprint("loading: "..hook)
   -- tprint(hook_config)
end

-- #################################################################

-- @brief Called, for every enabled hook, upon ntopng termination
-- @param hook The name of the enabled hook (e.g., min, hour)
-- @param hook_config A Lua table with the hook configuration
-- @return nil
function script.onUnload(hook, hook_config)
   tprint("unloading: "..hook)
   -- tprint(hook_config)
end

-- #################################################################

-- @brief Called when a user script hook is enabled
-- @param hook The name of the enabled hook (e.g., min, hour)
-- @param hook_config A Lua table with the hook configuration for the enabled hook
-- @return nil
function script.onEnable(hook, hook_config)
   tprint("[+] enabling: "..hook)
   -- tprint(hook_config)
end

-- #################################################################

-- @brief Called when a user script hook is disabled
-- @param hook The name of the disabled hook (e.g., min, hour)
-- @param hook_config A Lua table with the hook configuration for the disabled hook
-- @return nil
function script.onDisable(hook, hook_config)
   tprint("[-] disabling: "..hook)
   -- tprint(hook_config)
end

-- #################################################################

-- @brief Called when the configuration for an enabled user script hook has changed
-- @param hook The name of the hook (e.g., min, hour) for which the configuration has changed
-- @param hook_config A Lua table with the new (changed) configuration
-- @return nil
function script.onUpdateConfig(hook, hook_config)
   tprint("[~] config change: "..hook)
   -- tprint(hook_config)
end

-- #################################################################

-- @brief Called  when the user script is loaded 
-- @return true if the script should be loaded, false otherwise
-- @notes Can be used to init some script global state or to skip the script
-- execution on some particular conditions
function script.setup()
  local is_enabled = true -- your custom condition here

  global_state = {}

  return(is_enabled)
end

-- #################################################################

-- An hook executed every minute on the active hosts.
function script.hooks.min(info)
  --tprint(info)
  print("host:min hook called: " .. info.entity_info.ip)

  -- Full host information can be extracted with interface.getHostInfo
  --tprint(interface.getHostInfo(info.alert_entity.alert_entity_val))

  local alert_info = {
     alert_type = alert_consts.alert_types.alert_example,
     alert_severity = alert_severities.notice,
     alert_granularity = info.granularity,
     alert_type_params = {
	some_value = 1234,
     },
  }

  local bytes = host.getBytes()
  local tot_bytes = bytes["bytes.sent"] + bytes["bytes.rcvd"]

  if(tot_bytes > info.check_config.max_bytes) then
    -- Trigger alert
    alerts_api.trigger(info.alert_entity, alert_info)
  else
    -- Release previously triggered alert (if any)
    alerts_api.release(info.alert_entity, alert_info)
  end
end

-- #################################################################

-- An hook executed every 5 minutes on the active hosts.
script.hooks["5mins"] = function(info)
  print("host:5mins hook called: " .. info.entity_info.ip)
end

-- #################################################################

-- An hook executed every hour on the active hosts.
function script.hooks.hour(info)
  print("host:hour hook called: " .. info.entity_info.ip)
end

-- #################################################################

-- An hook executed every day on the active hosts.
function script.hooks.day(info)
  print("host:day hook called: " .. info.entity_info.ip)
end

-- #################################################################

return script
