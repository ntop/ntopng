--
-- (C) 2019-24 - ntop.org
--
require "lua_utils_get"
local checks = require("checks")
local alert_consts = require("alert_consts")
local flow_alert_keys = require "flow_alert_keys"
local description = ternary(ntop.isnEdge(), "flow_checks_config.dev_proto_not_allowed_nedge_description",
    "flow_checks_config.dev_proto_not_allowed_description")

-- #################################################################

local script = {
    -- Script category
    category = checks.check_categories.security,

    -- This script is only for alerts generation
    alert_id = flow_alert_keys.flow_alert_device_protocol_not_allowed,

    default_value = {},

    gui = {
        i18n_title = "alerts_dashboard.suspicious_device_protocol",
        i18n_description = description,
        i18n_url = getDeviceProtocolPoliciesUrl()
    }
}

-- #################################################################

return script
