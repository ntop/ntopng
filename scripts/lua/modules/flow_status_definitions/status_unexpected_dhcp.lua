local alert_consts = require("alert_consts")
local status_keys = require "flow_keys"

return {
    status_key = status_keys.ntopng.status_unexpected_dhcp_server,
    alert_type = alert_consts.alert_types.alert_unexpected_dhcp,
    i18n_title = "unexpected_dhcp.unexpected_dhcp_title",
    i18n_description = "unexpected_dhcp.status_unexpected_dhcp_description",
}
