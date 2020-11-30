--
-- (C) 2019-20 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_severities = require "alert_severities"
local alert_consts = require "alert_consts"
local user_scripts = require("user_scripts")

local script

-- #################################################################

local function check_interface_drops(params)
  local info = params.entity_info
  local num_dropped = info.stats.num_dropped_flow_scripts_calls
  local delta_dropped = alerts_api.interface_delta_val(script.key, params.granularity, num_dropped)
  local drops_type = alert_consts.alert_types.alert_user_script_calls_drops.create(
     alert_severities.error,
     alert_consts.alerts_granularities.min,
     "flow",
     delta_dropped
  )

  if(delta_dropped > 0) then
    alerts_api.trigger(params.alert_entity, drops_type, nil, params.cur_alerts)
  else
    alerts_api.release(params.alert_entity, drops_type, nil, params.cur_alerts)
  end
end

-- #################################################################

script = {
  -- Script category
  category = user_scripts.script_categories.internals,

  default_enabled = true,
  hooks = {
    min = check_interface_drops,
  },

  -- This script is only for alerts generation
  is_alert = true,

  gui = {
    i18n_title = "show_alerts.flow_user_scripts_drops_title",
    i18n_description = i18n("show_alerts.flow_user_scripts_drops_descr",
      {url=ntop.getHttpPrefix() .. "/lua/if_stats.lua?page=callbacks&tab=flows"}),
  }
}

-- #################################################################

return script
