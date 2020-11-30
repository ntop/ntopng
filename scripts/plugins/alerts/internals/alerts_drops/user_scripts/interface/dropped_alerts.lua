--
-- (C) 2019-20 - ntop.org
--

local user_scripts = require("user_scripts")
local alerts_api = require("alerts_api")
local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")

local script = {
  -- Script category
  category = user_scripts.script_categories.internals,

  -- This script is only for alerts generation
  is_alert = true,

  -- See below
  hooks = {},

  gui = {
    i18n_title = "internals.alert_drops",
    i18n_description = "internals.alert_drops_descr",
  },
}

-- #################################################################

local function dropped_alerts_check(params)
   local dropped_alerts = interface.getStats()["num_dropped_alerts"]

   -- Compute the delta with the previous value for drops
   local delta_drops = alerts_api.interface_delta_val(script.key, params.granularity, dropped_alerts, true --[[ skip first --]])

   local alert_type = alert_consts.alert_types.alert_dropped_alerts.create(
      alert_severities.error,
      alert_consts.alerts_granularities[params.granularity],
      interface.getId(),
      delta_drops
   )

   if(delta_drops > 0) then
      alerts_api.trigger(params.alert_entity, alert_type, nil, params.cur_alerts)
   else
      alerts_api.release(params.alert_entity, alert_type, nil, params.cur_alerts)
   end
end

-- #################################################################

script.hooks.min = dropped_alerts_check

-- #################################################################

return script
