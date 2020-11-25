local alert_consts = require("alert_consts")
local status_keys = require "flow_keys"

local function formatUnexpected(flowstatus_info)
   return(i18n("unexpected_dns.status_unexpected_dns_description", { server=flowstatus_info.server_ip} ))
end
   
return {
    status_key = status_keys.ntopng.status_unexpected_dns_server,
    alert_type = alert_consts.alert_types.alert_unexpected_dns,
    i18n_title = "unexpected_dns.unexpected_dns_title",
    i18n_description = formatUnexpected
}
