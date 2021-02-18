--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"
local alert_consts = require "alert_consts"


-- #################################################################

local script = {
  -- Script category
  category = user_scripts.script_categories.network,

  -- NOTE: hooks defined below
  hooks = {},

  -- This script is only for alerts generation
  is_alert = true,

  default_value = {
    severity = alert_severities.notice,
  },

  gui = {
    i18n_title = "flow_callbacks_config.remote_to_remote",
    i18n_description = "flow_callbacks_config.remote_to_remote_description",
  }
}

-- #################################################################

function script.hooks.protocolDetected(now, conf)
   if(flow.isRemoteToRemote() and flow.isUnicast()) then
    local alert = alert_consts.alert_types.alert_remote_to_remote.new()

      alert:set_severity(conf.severity)

      alert:trigger_status(10 --[[ cli score --]], 10 --[[ srv score --]], 10 --[[ flow score --]])
  end
end

-- #################################################################

return script
