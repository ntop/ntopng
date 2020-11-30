--
-- (C) 2019-20 - ntop.org
--

local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"
local flow_consts = require "flow_consts"
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

      local status_type = flow_consts.status_types.status_new_api_demo.create(
	 "one_param",
	 "another_param"
      )

      alerts_api.trigger_status(status_type, alert_severities.error, cli_score, srv_score, flow_score)
   end
end

-- #################################################################

return script
