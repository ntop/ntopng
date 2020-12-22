--
-- (C) 2019-20 - ntop.org
--

local flow_consts = require("flow_consts")
local user_scripts = require("user_scripts")
local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"

-- #################################################################

local script = {
  -- Script category
  category = user_scripts.script_categories.security,

  -- NOTE: hooks defined below
  hooks = {},

  gui = {
    i18n_title = "flow_callbacks_config.web_mining",
    i18n_description = "flow_callbacks_config.web_mining_description",
  }
}

-- #################################################################

function script.hooks.protocolDetected(now)
   if(flow.getnDPICategoryName() == "Mining") then
      local web_mining_detected_type = flow_consts.status_types.status_web_mining_detected.create()

      alerts_api.trigger_status(web_mining_detected_type, alert_severities.error, 50, 10, 50)
   end
end

-- #################################################################

return script
