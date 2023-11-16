--
-- (C) 2019-22 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local checks = require("checks")

local script = {
  -- Script category
  category = checks.check_categories.network,

  default_enabled = false,

  default_value = {
    -- "> 5%"
    operator = "gt",
    threshold = 80,
  },

  severity = alert_consts.get_printable_severities().error,
  -- See below
  hooks = {},

  gui = {
    i18n_title = "alerts_thresholds_config.throughput",
    i18n_description = "alerts_thresholds_config.alert_throughput_description",
    i18n_field_unit = checks.field_units.percentage,
    input_builder = "threshold_cross",
    field_max = 99,
    field_min = 1,
    field_operator = "gt";
  }
}

-- #################################################################

function script.hooks.min(params)
  local interface_bytes = params.entity_info["stats"]["bytes"]
  local interface_speed = params.entity_info["speed"]
  local perc_threshold = tonumber(params.check_config.threshold)
  local threshold = interface_speed * (perc_threshold / 100)

  -- Delta
  local value = alerts_api.interface_delta_val(script.key, params.granularity, interface_bytes)
  -- Granularity
  value = value / alert_consts.granularity2sec(params.granularity)
  -- Bytes to Mbit, the Interface speed is in Mbit
  value = (value * 8) / 1000000

  local alert = alert_consts.alert_types.alert_threshold_cross.new(
    params.check.key,
    value,
    params.check_config.operator,
    threshold
  )

  alert:set_info(params)

  if(value > threshold) then
    alert:trigger(params.alert_entity, nil, params.cur_alerts)
  else
    alert:release(params.alert_entity, nil, params.cur_alerts)
  end
end

-- #################################################################

return script
