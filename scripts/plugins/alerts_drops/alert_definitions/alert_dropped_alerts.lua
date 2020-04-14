--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

local function formatDroppedAlerts(ifid, alert, alert_info)
  return(i18n("alert_messages.iface_alerts_dropped", {
    iface = getHumanReadableInterfaceName(alert_info.ifid),
    num_dropped = alert_info.num_dropped,
    url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid=" .. alert_info.ifid
  }))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_dropped_alerts,
  i18n_title = i18n("show_alerts.dropped_alerts"),
  icon = "fas fa-exclamation-triangle",
  i18n_description = formatDroppedAlerts,
}
