--
-- (C) 2019-21 - ntop.org
--

local checks = require("checks")
local host_alert_keys = require "host_alert_keys"

-- #################################################################

local p2p = {
  -- Script category
  category = checks.check_categories.network,

  default_enabled = false,
  alert_id = host_alert_keys.host_alert_p2p_traffic,

  default_value = {
    operator = "gt",
  },

  gui = {
    i18n_title = "alerts_thresholds_config.p2p_traffic",
    i18n_description = "alerts_thresholds_config.alert_p2p_description",
    i18n_field_unit = checks.field_units.bytes,
    input_builder = "threshold_cross",
    field_operator = "gt";
  },
}

-- #################################################################

return p2p
