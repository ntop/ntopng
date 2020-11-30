--
-- (C) 2019-20 - ntop.org
--

local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")
local alerts_api = require("alerts_api")
local user_scripts = require("user_scripts")

local script

-- ##############################################

local function alert_info(ps_name, max_duration_ms)
   local alert_info = alert_consts.alert_types.alert_slow_periodic_activity.create(
      alert_severities.warning,
      alert_consts.alerts_granularities.min,
      ps_name,
      max_duration_ms
   )

   return alert_info
end

-- #################################################################

local function check_slow_periodic_activity(params)
   local scripts_stats = interface.getPeriodicActivitiesStats()

   for ps_name, ps_stats in pairs(scripts_stats) do
      local delta = alerts_api.interface_delta_val(script.key..ps_name --[[ metric name --]], params.granularity, ps_stats["num_is_slow"] or 0)
      
      local info = alert_info(ps_name, (ps_stats["max_duration_secs"] or 0) * 1000)

      if delta > 0 then
	 -- tprint({ps_name = ps_name, s = ">>>>>>>>>>>>>>>>>>>>>> TRIGGER"})
	 alerts_api.trigger(params.alert_entity, info, nil, params.cur_alerts)
      else
	 -- tprint({ps_name = ps_name, s = "---------------------- RELEASE"})
	 alerts_api.release(params.alert_entity, info, nil, params.cur_alerts)
      end
   end
end

-- #################################################################

script = {
   -- Script category
   category = user_scripts.script_categories.internals,

   -- This script is only for alerts generation
   is_alert = true,

   hooks = {
      min = check_slow_periodic_activity,
   },

   gui = {
      i18n_title = "alerts_dashboard.slow_periodic_activity",
      i18n_description = "alerts_dashboard.slow_periodic_activity_descr",
   }
}

-- #################################################################

return script
