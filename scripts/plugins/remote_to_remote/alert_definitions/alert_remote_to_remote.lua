--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

local function remoteToRemoteFormatter(ifid, alert, info)
  return(i18n("alert_messages.host_remote_to_remote", {
    url = ntop.getHttpPrefix() .. "/lua/host_details.lua?host=" .. hostinfo2hostkey(hostkey2hostinfo(alert.alert_entity_val)),
    flow_alerts_url = ntop.getHttpPrefix() .."/lua/show_alerts.lua?status=historical-flows&alert_type="..alertType("alert_remote_to_remote"),
    mac_url = ntop.getHttpPrefix() .."/lua/mac_details.lua?host="..info.mac,
    ip = info.host,
    mac = get_symbolic_mac(info.mac, true),
  }))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_remote_to_remote,
  i18n_title = "alerts_dashboard.remote_to_remote",
  i18n_description = remoteToRemoteFormatter,
  icon = "fas fa-exclamation",
}
