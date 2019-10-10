--
-- (C) 2019 - ntop.org
--

local alerts_api = require "alerts_api"
local alert_consts = require "alert_consts"
local user_scripts = require("user_scripts")
local do_trace = false

-- #################################################################

local script = {
   key = "blacklisted",

   -- NOTE: hooks defined below
   hooks = {},

   gui = {
      i18n_title = "flow_callbacks_config.blacklisted",
      i18n_description = "flow_callbacks_config.blacklisted_description",
      input_builder = user_scripts.flow_checkbox_input_builder,
   }
}

-- #################################################################

function script.setup()
   return false -- TODO: activate when migration to lua flow alerts completed
end

-- #################################################################

function script.hooks.protocolDetected(flow_info)
   if flow_info["cli.blacklisted"] or flow_info["srv.blacklisted"] then
      alerts_api.storeFlowAlert(alert_consts.alert_types.flow_blacklisted, alert_consts.alert_severities.error, flow_info)
   end
end

-- #################################################################

return script
