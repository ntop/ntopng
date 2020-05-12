--
-- (C) 2019-20 - ntop.org
--

local status_keys = require "flow_keys"

local alert_consts = require("alert_consts")

-- #################################################################

return {
  status_key = status_keys.ntopng.status_binary_application_transfer,
  alert_severity = alert_consts.alert_severities.error,
  -- scripts/lua/modules/alert_keys.lua
  alert_type = alert_consts.alert_types.alert_binary_application_transfer,
  -- scripts/locales/en.lua
  i18n_title = "alerts_dashboard.binary_application_transfer"
}
