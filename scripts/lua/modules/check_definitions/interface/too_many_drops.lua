--
-- (C) 2019-22 - ntop.org
--

local alerts_api = require("alerts_api")
local checks = require("checks")
local alert_consts = require("alert_consts")

-- #################################################################

local script = {
  -- Script category
  category = checks.check_categories.system,

  default_enabled = true,
  default_value = {
    -- "> 5%"
    operator = "gt",
    threshold = 5,
  },

  severity = alert_consts.get_printable_severities().error,
  hooks = {},

  gui = {
    i18n_title = "alerts_dashboard.too_many_drops",
    i18n_description = "show_alerts.interface_drops_threshold_descr",
    i18n_field_unit = checks.field_units.percentage,
    input_builder = "threshold_cross",
    field_max = 99,
    field_min = 1,
    field_operator = "gt";
  }
}

-- #################################################################

local function check_interface_drops(params)
  local info = params.entity_info
  local stats = info.stats_since_reset
  local threshold = tonumber(params.check_config.threshold)
  local drop_perc = math.min(stats.drops * 100.0 / (stats.drops + stats.packets + 1), 100)
  
  local alert = alert_consts.alert_types.alert_too_many_drops.new(
    stats.drops,
    drop_perc,
    threshold
    )

  alert:set_info(params)
  alert:set_subtype(getInterfaceName(interface.getId()))

  if((stats.packets > 100) and (drop_perc > threshold)) then
    alert:trigger(params.alert_entity, nil, params.cur_alerts)
  else
    alert:release(params.alert_entity, nil, params.cur_alerts)
  end
end

-- #################################################################

script.hooks.min = check_interface_drops

-- #################################################################

return script
