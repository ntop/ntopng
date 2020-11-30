--
-- (C) 2019-20 - ntop.org
--

local alerts_api = require("alerts_api")
local user_scripts = require("user_scripts")

local script

-- #################################################################

local function check_interface_drops(params)
  local alert_severities = require "alert_severities"
  local alert_consts = require "alert_consts"
  local info = params.entity_info
  local stats = info.stats_since_reset
  local threshold = tonumber(params.user_script_config.threshold)
  local drop_perc = math.min(stats.drops * 100.0 / (stats.drops + stats.packets + 1), 100)
  local drops_type = alert_consts.alert_types.alert_too_many_drops.create(
     alert_severities.error,
     alert_consts.alerts_granularities.min,
     stats.drops,
     drop_perc,
     threshold
  )

  if((stats.packets > 100) and (drop_perc > threshold)) then
     alerts_api.trigger(params.alert_entity, drops_type, nil, params.cur_alerts)
  else
    alerts_api.release(params.alert_entity, drops_type, nil, params.cur_alerts)
  end
end

-- #################################################################

script = {
  -- Script category
  category = user_scripts.script_categories.system,

  default_enabled = true,
  default_value = {
    -- "> 5%"
    operator = "gt",
    threshold = 5,
  },

  -- This script is only for alerts generation
  is_alert = true,

  hooks = {
    min = check_interface_drops,
  },

  gui = {
    i18n_title = "show_alerts.interface_drops_threshold",
    i18n_description = "show_alerts.interface_drops_threshold_descr",
    i18n_field_unit = user_scripts.field_units.percentage,
    input_builder = "threshold_cross",
    field_max = 99,
    field_min = 1,
    field_operator = "gt";
  }
}

-- #################################################################

return script
