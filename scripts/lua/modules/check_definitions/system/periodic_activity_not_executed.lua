--
-- (C) 2019-22 - ntop.org
--

local alert_consts = require("alert_consts")
local alerts_api = require("alerts_api")
local checks = require("checks")

local script = {
  -- Script category
  category = checks.check_categories.internals,
  severity = alert_consts.get_printable_severities().error,

  hooks = {},

  gui = {
    i18n_title = "alerts_dashboard.periodic_activity_not_executed",
    i18n_description = "alerts_dashboard.periodic_activity_not_executed_descr",
  }
}

-- #################################################################

local function check_periodic_activity_not_executed(params)
   local scripts_stats = interface.getPeriodicActivitiesStats()

   for ps_name, ps_stats in pairs(scripts_stats) do
      local delta = alerts_api.interface_delta_val(script.key..ps_name --[[ metric name --]], params.granularity, ps_stats["num_not_executed"] or 0)

      local alert = alert_consts.alert_types.alert_periodic_activity_not_executed.new(
         ps_stats["last_queued_time"] or 0
      )

      alert:set_info(params)
      alert:set_subtype(ps_name)
      
      if delta > 0 then
	 -- tprint({ps_name = ps_name, s = ">>>>>>>>>>>>>>>>>>>>>> TRIGGER"})
         alert:trigger(params.alert_entity, nil, params.cur_alerts)
      else
	 -- tprint({ps_name = ps_name, s = "---------------------- RELEASE"})
         alert:release(params.alert_entity, nil, params.cur_alerts)
      end
   end
end

-- #################################################################

script.hooks.min = check_periodic_activity_not_executed

-- #################################################################

return script
