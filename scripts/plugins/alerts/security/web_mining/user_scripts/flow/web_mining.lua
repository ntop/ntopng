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
    items = {},
  },

  -- NOTE: hooks defined below
  hooks = {},

  gui = {
    i18n_title = "flow_callbacks_config.web_mining",
    i18n_description = "flow_callbacks_config.web_mining_description",
  }
}

-- #################################################################

function script.hooks.protocolDetected(now, conf)
   if(flow.getnDPICategoryName() == "Mining") then
      local alert = alert_consts.alert_types.alert_web_mining.new()

      alert:set_severity(conf.severity)

      alert:trigger_status(50, 10, 50)
   end
end

-- #################################################################

return script
