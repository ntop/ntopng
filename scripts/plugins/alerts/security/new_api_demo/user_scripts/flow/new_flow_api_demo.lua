--
-- (C) 2019-20 - ntop.org
--

local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"
local alert_consts = require "alert_consts"
local alerts_api = require "alerts_api"

-- #################################################################

local script = {
   -- Script category
   category = user_scripts.script_categories.security, 

   -- NOTE: hooks defined below
   hooks = {},

   gui = {
      i18n_title = "New API Demo",
      i18n_description = "Demonstrate the use of the new API for flow alerts",
   }
}

-- #################################################################

function script.hooks.protocolDetected(now)
   if false then -- TODO: set to true to execute
      local cli_score, srv_score, flow_score = 10, 10, 10
      local alert = alert_consts.alert_types.alert_flow_new_api_demo.new(
	 "one_flow_param",
	 "another_flow_param"
      )

      alert:set_severity(alert_severities.error)

      alert:trigger_status(cli_score, srv_score, flow_score)
   end
end

-- #################################################################

return script
