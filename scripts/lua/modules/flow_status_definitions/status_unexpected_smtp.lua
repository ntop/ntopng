local alert_consts = require("alert_consts")
local status_keys = require "flow_keys"

return {
    status_key = status_keys.ntopng.status_unexpected_smtp_server,
    alert_type = alert_consts.alert_types.alert_unexpected_smtp,
    i18n_title = "unexpected_smtp.unexpected_smtp_title",
    i18n_description = "unexpected_smtp.status_unexpected_smtp_description",
}
