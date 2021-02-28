--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"
local alerts_api = require "alerts_api"
local alert_consts = require("alert_consts")

-- #################################################################

local script = {
   local_only = true,

   default_enabled = true,
   
   -- Script category
   category = user_scripts.script_categories.security, 

   -- This script is only for alerts generation
   is_alert = true,
   
   default_value = {
      severity = alert_severities.warning,
   },

   -- NOTE: hooks defined below
   hooks = {},

   gui = {
      i18n_title = "alerts_dashboard.unexpected_host_behaviour_title",
      i18n_description = "alerts_dashboard.sites_behaviour_description",
   }
}

-- #################################################################

function script.hooks.min(params)
   local stats = host.getBehaviourInfo() or nil

   if stats then
      if stats["contacted_hosts_behavior.hw_value"] ~= nil then 
      	 local value = stats["contacted_hosts_behavior.hw_value"]	
      	 local prediction = stats["contacted_hosts_behavior.hw_prediction"]
      	 local estimated_value = stats["contacted_hosts_behavior.last_hll_estimate"]
      	 local upper_bound = stats["contacted_hosts_behavior.hw_upper_bound"]
      	 local lower_bound = stats["contacted_hosts_behavior.hw_lower_bound"]

      	 local alert = alert_consts.alert_types.alert_unexpected_behaviour.new(
            "Domain visited", -- Type of unexpected behaviour
            estimated_value,
            prediction,
	    upper_bound,
	    lower_bound
         )

         alert:set_severity(conf.severity)

         if value == true then
            alert:trigger(params.alert_entity, nil, params.cur_alerts)
         else
	    alert:release(params.alert_entity, nil, params.cur_alerts)
         end
      end
   end
end

-- #################################################################

return script
