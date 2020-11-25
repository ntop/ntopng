local alert_consts = require("alert_consts")
local status_keys = require "flow_keys"

local function formatUnexpected(flowstatus_info)
   return(i18n("unexpected_ntp.status_unexpected_ntp_description", { server=flowstatus_info.server_ip} ))
end

return {
    status_key = status_keys.ntopng.status_unexpected_ntp_server,
    alert_type = alert_consts.alert_types.alert_unexpected_ntp,
    i18n_title = "unexpected_ntp.unexpected_ntp_title",
    i18n_description = formatUnexpected
}
