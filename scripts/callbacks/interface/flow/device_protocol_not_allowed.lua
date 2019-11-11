--
-- (C) 2019 - ntop.org
--

local flow_consts = require("flow_consts")
local user_scripts = require("user_scripts")

-- #################################################################

local script = {
  -- NOTE: hooks defined below
  hooks = {},

  gui = {
    i18n_title = "flow_callbacks_config.dev_proto_not_allowed",
    i18n_description = i18n(
      ternary(ntop.isnEdge(), "flow_callbacks_config.dev_proto_not_allowed_nedge_description", "flow_callbacks_config.dev_proto_not_allowed_description"),
      {url = getDeviceProtocolPoliciesUrl()}),
    input_builder = user_scripts.flow_checkbox_input_builder,
  }
}

-- #################################################################

function script.hooks.protocolDetected(now)
  local proto_info = flow.getDeviceProtoAllowedInfo()

  if((not proto_info["cli.allowed"]) or (not proto_info["srv.allowed"])) then
    local alert_info = {
      ["cli.devtype"] = proto_info["cli.devtype"],
      ["srv.devtype"] = proto_info["srv.devtype"],
    }

    if(not proto_info["cli.allowed"]) then
      alert_info["devproto_forbidden_peer"] = "cli"
      alert_info["devproto_forbidden_id"] = proto_info["cli.disallowed_proto"]
    else
      alert_info["devproto_forbidden_peer"] = "srv"
      alert_info["devproto_forbidden_id"] = proto_info["srv.disallowed_proto"]
    end

    flow.triggerStatus(flow_consts.status_types.status_device_protocol_not_allowed.status_id, alert_info)
  end
end

-- #################################################################

return script
