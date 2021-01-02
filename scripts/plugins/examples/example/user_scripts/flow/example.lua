--
-- (C) 2019-21 - ntop.org
--


-- This is a user script executed by scripts/callbacks/interface/flow.lua .
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
    exclude_ports = {[80] = true},
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
    i18n_title = "example.flow_script_title",

    -- A description for this user script
    i18n_description = "example.flow_script_description",
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

  -- If true, the script will be executed on TCP flows only after the three
  -- way handshake is completed
  three_way_handshake_ok = false,

  -- If set, the script will only be called on flows with the specified
  -- L7 protocol name (application or master protocol).
  -- Run "ntopng --print-ndpi-protocols" to get a list of protocol names.
  l7_proto = nil,

  -- If set, the script will only be called on flows with the specified
  -- L4 protocol name. Supported values: udp, tcp, icmp
  l4_proto = nil,
}

-- #################################################################

-- @brief See host/example.lua
function script.onLoad(hook, hook_config)
   tprint("loading: "..hook)
   -- tprint(hook_config)
end

-- #################################################################

-- @brief See host/example.lua
function script.onUnload(hook, hook_config)
   tprint("unloading: "..hook)
   -- tprint(hook_config)
end

-- #################################################################

-- @brief See host/example.lua
function script.onEnable(hook, hook_config)
   tprint("[+] enabling: "..hook)
   -- tprint(hook_config)
end

-- #################################################################

-- @brief See host/example.lua
function script.onDisable(hook, hook_config)
   tprint("[-] disabling: "..hook)
   -- tprint(hook_config)
end

-- #################################################################

-- @brief See host/example.lua
function script.onUpdateConfig(hook, hook_config)
   tprint("[~] config change: "..hook)
   -- tprint(hook_config)
end

-- #################################################################

-- @brief Called when the script is going to be loaded.
-- @return true if the script should be loaded, false otherwise
-- @note Can be used to init some script global state or to skip the script
-- execution on some particular conditions
function script.setup()
  local is_enabled = true -- your custom condition here

  global_state = {}

  return(is_enabled)
end

-- #################################################################

-- An hook executed after the protocol of a flow has been detected
function script.hooks.protocolDetected(now, config)
  local flow_info = flow.getInfo()

  print("flow:protocolDetected hook called: " .. shortFlowLabel(flow_info))

  -- Check if the server port is not in the configured exclusion list
  if not config["exclude_ports"][flow_info["srv.port"]] then
    -- Set an invalid status on the flow and trigger the corresponding alert
    flow.triggerStatus(flow_consts.status_types.status_example, {
      bad_port = flow_info["srv.port"]
    }, 60--[[ flow score]], 50--[[ cli score ]], 10--[[ srv score ]])
  else
    -- A previosly set status can be cleared
    -- flow.clearStatus(flow_consts.status_types.status_example)
  end
end

-- #################################################################

-- An hook executed when the flow is considered closed
function script.hooks.flowEnd(now, config)
  print("flow:protocolDetected hook called: " .. shortFlowLabel(flow.getInfo()))
end

-- #################################################################

-- An hook executed periodically
function script.hooks.periodicUpdate(now, config)
  print("flow:periodicUpdate hook called: " .. shortFlowLabel(flow.getInfo()))
end

-- #################################################################

return script
