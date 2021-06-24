--
-- (C) 2019-21 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local checks = require("checks")

-- #################################################################

local function check_interface_idle(params)
  local threshold = tonumber(params.check_config.threshold)
  local engage = false
  local max_idle = 0
  local max_idle_perc = 0

  local hash_tables_stats = interface.getHashTablesStats()
  for ht_name, ht_stats in pairsByKeys(hash_tables_stats, asc) do
    local idle = ht_stats["hash_entry_states"]["hash_entry_state_idle"] or 0
    local active = ht_stats["hash_entry_states"]["hash_entry_state_active"] or 0
    local idle_perc = math.min(idle * 100.0 / (idle + active + 1), 100)
    if (idle + active) > 1024 and idle_perc > threshold then
      if idle_perc > max_idle_perc then
        max_idle = idle
        max_idle_perc = idle_perc
      end
    end
  end

  local alert = alert_consts.alert_types.alert_slow_purge.new(
    max_idle,
    max_idle_perc,
    threshold
  )

  alert:set_score_warning()
  alert:set_subtype(getInterfaceName(interface.getId()))
  alert:set_granularity(params.granularity)

  if max_idle_perc > threshold then
    alert:trigger(params.alert_entity, nil, params.cur_alerts)
  else
    alert:release(params.alert_entity, nil, params.cur_alerts)
  end
end

-- #################################################################

local script = {
  -- Script category
  category = checks.check_categories.internals,

  default_enabled = true,
  default_value = {
    -- "> 50%"
    operator = "gt",
    threshold = 50,
  },


  hooks = {
    min = check_interface_idle,
  },

  gui = {
    i18n_title = "alerts_thresholds_config.alert_slow_purge_threshold",
    i18n_description = "alerts_thresholds_config.alert_slow_purge_threshold_descr",
    i18n_field_unit = checks.field_units.percentage,
    input_builder = "threshold_cross",
    field_max = 99,
    field_min = 1,
    field_operator = "gt";
  }
}

-- #################################################################

return script
