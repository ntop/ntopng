--
-- (C) 2019-24 - ntop.org
--

local checks = require("checks")
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
  -- Script category
  category = checks.check_categories.warning, 

  -- This script is only for alerts generation
  alert_id = flow_alert_keys.flow_alert_ndpi_probing_attempt,

  default_enabled = true,

  default_value = {
  },

  gui = {
    i18n_title = "flow_risk.tcp_probing_attempt",
    i18n_description = "flow_risk.tcp_probing_attempt",
  }
}

-- #################################################################

return script
