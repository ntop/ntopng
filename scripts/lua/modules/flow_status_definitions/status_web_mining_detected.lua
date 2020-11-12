--
-- (C) 2019-20 - ntop.org
--

local status_keys = require "flow_keys"

local alert_consts = require("alert_consts")

-- #################################################################

return {
  status_key = status_keys.ntopng.status_web_mining_detected,
  alert_type = alert_consts.alert_types.alert_web_mining,
  i18n_title = "flow_details.web_mining_detected"
}
