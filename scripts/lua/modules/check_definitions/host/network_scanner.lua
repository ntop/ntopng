local checks = require("checks")
local host_alert_keys = require "host_alert_keys"
local alert_consts = require("alert_consts")
local field_units = require "field_units"

local network_scanner = {
    category = checks.check_categories.network,
    severity = alert_consts.get_printable_severities().warning,
    default_enabled = false,
    alert_id = host_alert_keys.host_alert_network_scanner,
    default_value = {
        operator = "gt",
        threshold = 5,
    },
    gui = {
        i18n_title = "alerts_dashboard.network_scanner_title",
        i18n_description = "alerts_dashboard.network_scanner_description",
        i18n_field_unit = checks.field_units.count,
        input_builder = "threshold_cross",
        i18n_field_unit = field_units.flows,
        field_max = 65535,
        field_min = 1,
        field_operator = "gt",
    }
}

return network_scanner