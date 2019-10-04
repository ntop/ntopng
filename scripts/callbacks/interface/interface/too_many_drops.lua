--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")

local check_module

-- #################################################################

local function check_interface_drops(params)
  local info = params.entity_info
  local stats = info.stats_since_reset
  local threshold = tonumber(params.alert_config.edge)
  local drop_perc = math.min(stats.drops * 100.0 / (stats.drops + stats.packets + 1), 100)
  local drops_type = alerts_api.tooManyDropsType(stats.drops, drop_perc, threshold)

  if((stats.packets > 100) and (drop_perc > threshold)) then
    alerts_api.trigger(params.alert_entity, drops_type)
  else
    alerts_api.release(params.alert_entity, drops_type)
  end
end

-- #################################################################

check_module = {
  key = "too_many_drops",
  granularity = {"min"},
  check_function = check_interface_drops,
  default_value = "too_many_drops;gt;5", -- 5%

  gui = {
    i18n_title = "show_alerts.interface_drops_threshold",
    i18n_description = "show_alerts.interface_drops_threshold_descr",
    i18n_field_unit = alert_consts.field_units.percentage,
    input_builder = alerts_api.threshold_cross_input_builder,
    field_max = 99,
    field_min = 1,
    field_operator = "gt";
  }
}

-- #################################################################

return check_module
