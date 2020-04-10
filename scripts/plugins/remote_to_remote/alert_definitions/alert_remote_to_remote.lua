--
-- (C) 2019-20 - ntop.org
--

local function remoteToRemoteFormatter(ifid, alert, info)
  local alert_consts = require "alert_consts"

  return(i18n("alert_messages.host_remote_to_remote", {
    url = ntop.getHttpPrefix() .. "/lua/host_details.lua?host=" .. hostinfo2hostkey(hostkey2hostinfo(alert.alert_entity_val)),
    flow_alerts_url = ntop.getHttpPrefix() .."/lua/show_alerts.lua?status=historical-flows&alert_type="..alert_consts.alertType("alert_remote_to_remote"),
    mac_url = ntop.getHttpPrefix() .."/lua/mac_details.lua?host="..info.mac,
    ip = info.host,
    mac = get_symbolic_mac(info.mac, true),
  }))
end

-- #######################################################

return {
  i18n_title = "alerts_dashboard.remote_to_remote",
  i18n_description = remoteToRemoteFormatter,
  icon = "fas fa-exclamation",
}
