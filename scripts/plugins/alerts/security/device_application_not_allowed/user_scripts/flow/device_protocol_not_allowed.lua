--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")

-- #################################################################

local script = {
  -- Script category
  category = user_scripts.script_categories.security, 

  -- This script is only for alerts generation
  is_alert = true,

  default_value = {
    severity = alert_severities.error,
  },

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

function script.hooks.protocolDetected(now, conf)
  if(flow.isDeviceProtocolNotAllowed()) then
    local proto_info = flow.getDeviceProtoAllowedInfo()
    local flow_score = 80
    local cli_score, srv_score, attacker, victim
    local flow_info = flow.getInfo()

    local alert_info = {
      ["cli.devtype"] = proto_info["cli.devtype"],
      ["srv.devtype"] = proto_info["srv.devtype"],
    }

    if(not proto_info["cli.allowed"]) then
      alert_info["devproto_forbidden_peer"] = "cli"
      alert_info["devproto_forbidden_id"] = proto_info["cli.disallowed_proto"]
      cli_score = 80
      srv_score = 5
      attacker = flow_info["cli.ip"]
      victim = flow_info["srv.ip"]
    else
      alert_info["devproto_forbidden_peer"] = "srv"
      alert_info["devproto_forbidden_id"] = proto_info["srv.disallowed_proto"]
      cli_score = 5
      srv_score = 80
      attacker = flow_info["srv.ip"]
      victim = flow_info["cli.ip"]
    end

    local alert = alert_consts.alert_types.alert_device_protocol_not_allowed.new(
      alert_info["cli.devtype"],
      alert_info["srv.devtype"],
      alert_info["devproto_forbidden_peer"],
      alert_info["devproto_forbidden_id"]
    )

    alert:set_severity(conf.severity)
    alert:set_attacker(attacker)
    alert:set_victim(victim)

    alert:trigger_status(cli_score, srv_score, flow_score)
  end
end

-- #################################################################

return script
