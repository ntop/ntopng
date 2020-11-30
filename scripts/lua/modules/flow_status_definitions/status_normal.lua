--
-- (C) 2019-20 - ntop.org
--

local status_keys = require "flow_keys"

local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")

-- #################################################################

return {
  status_key = status_keys.ntopng.status_normal,
  alert_severity = alert_severities.info,
  alert_type = alert_consts.alert_types.alert_none,
  i18n_title = "flow_details.normal",
}
