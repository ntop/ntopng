--
-- (C) 2019-20 - ntop.org
--

local user_scripts = require("user_scripts")
local alert_consts = require("alert_consts")
local flow_consts = require "flow_consts"
local alerts_api = require "alerts_api"

-- #################################################################

local script = {
   -- Script category
   category = user_scripts.script_categories.security,

   -- NOTE: hooks defined below
   hooks = {},

   gui = {
      i18n_title = "New Host Alert API Demo",
      i18n_description = "Demonstrate the use of the new API for host alerts",
   }
}

-- #################################################################

function script.hooks.min(params)
   if true then -- TODO: set to true to execute
      local Alert = alert_consts.alert_types.alert_host_new_api_demo.new()

      Alert:set_severity(alert_consts.alert_severities.error)
      Alert:set_granularity(params.granularity)

      Alert:set_params(
	 "one_param",
	 "another_param"
      )

      if cond then
	 Alert:set_attacker()
      end

      if another_cond then
	 Alert:set_victim()
      end

      if true then
	 Alert:trigger(params.alert_entity, nil, params.cur_alerts)
      else
	 Alert:release(params.alert_entity, nil, params.cur_alerts)
      end
   end
end

-- #################################################################

return script
