--
-- (C) 2019-20 - ntop.org
--

local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"
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
   if false then -- TODO: set to true to execute
      local alert = alert_consts.alert_types.alert_host_new_api_demo.new(
	 "one_param",
	 "another_param"
      )

      alert:set_severity(alert_severities.error)
      alert:set_granularity(params.granularity)

      if cond then
	 alert:set_attacker()
      end

      if another_cond then
	 alert:set_victim()
      end

      if true then
	 alert:trigger(params.alert_entity, nil, params.cur_alerts)
      else
	 alert:release(params.alert_entity, nil, params.cur_alerts)
      end
   end
end

-- #################################################################

return script
