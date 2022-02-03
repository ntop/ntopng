--
-- (C) 2019-21 - ntop.org
--

local checks = require("checks")
local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")

local script = {
  -- Script category
  category = checks.check_categories.internals,


  -- See below
  hooks = {},

  gui = {
    i18n_title = "internals.alert_drops",
    i18n_description = "internals.system_alert_drops_descr",
  },
}

-- #################################################################

local function dropped_alerts_check(params)
   -- Fetch system host stats
   local system_host_stats =  ntop.systemHostStat()

   -- Fetch the number of dropped alerts out of system host stats
   -- The number fetched is the number of drops occured in the internal queue, that is,
   -- in the queue currently used to generate alerts from C
   local dropped_alerts = system_host_stats["alerts_stats"]["alert_queues"]["internal_alerts_queue"]["num_not_enqueued"]

   -- Compute the delta with the previous value for drops
   local delta_drops = alerts_api.interface_delta_val(script.key, params.granularity, dropped_alerts, true --[[ skip first --]])
   
   local alert = alert_consts.alert_types.alert_dropped_alerts.new(
      interface.getId(),
      delta_drops
      )

   alert:set_score_error()
   alert:set_granularity(params.granularity)

   if(delta_drops > 0) then
      alert:trigger(params.alert_entity, nil, params.cur_alerts)
   else
      alert:release(params.alert_entity, nil, params.cur_alerts)
   end
end

-- #################################################################

script.hooks.min = dropped_alerts_check

-- #################################################################

return script
