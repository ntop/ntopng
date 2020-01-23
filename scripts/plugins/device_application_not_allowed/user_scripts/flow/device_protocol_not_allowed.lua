--
-- (C) 2019-20 - ntop.org
--

local flow_consts = require("flow_consts")
local user_scripts = require("user_scripts")

-- #################################################################

local script = {
  -- Script category
  category = user_scripts.script_categories.security, 

  -- NOTE: hooks defined below
  hooks = {},

  gui = {
    i18n_title = "flow_callbacks_config.dev_proto_not_allowed",
    i18n_description = i18n(
      ternary(ntop.isnEdge(), "flow_callbacks_config.dev_proto_not_allowed_nedge_description", "flow_callbacks_config.dev_proto_not_allowed_description"),
      {url = getDeviceProtocolPoliciesUrl()}),
  }
}

-- #################################################################

function script.hooks.protocolDetected(now)
  if(flow.isDeviceProtocolNotAllowed()) then
    local proto_info = flow.getDeviceProtoAllowedInfo()
    local flow_score = 80
    local cli_score, srv_score

    local alert_info = {
      ["cli.devtype"] = proto_info["cli.devtype"],
      ["srv.devtype"] = proto_info["srv.devtype"],
    }

    if(not proto_info["cli.allowed"]) then
      alert_info["devproto_forbidden_peer"] = "cli"
      alert_info["devproto_forbidden_id"] = proto_info["cli.disallowed_proto"]
      cli_score = 80
      srv_score = 5
    else
      alert_info["devproto_forbidden_peer"] = "srv"
      alert_info["devproto_forbidden_id"] = proto_info["srv.disallowed_proto"]
      cli_score = 5
      srv_score = 80
    end

    flow.triggerStatus(flow_consts.status_types.status_device_protocol_not_allowed, alert_info,
      flow_score, cli_score, srv_score)
  end
end

-- #################################################################

return script
