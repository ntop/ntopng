--
-- (C) 2019-20 - ntop.org
--

local function formatDroppedAlerts(ifid, alert, alert_info)
  return(i18n("alert_messages.iface_alerts_dropped", {
    iface = getHumanReadableInterfaceName(alert_info.ifid),
    num_dropped = alert_info.num_dropped,
    url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid=" .. alert_info.ifid
  }))
end

-- #######################################################

return {
  i18n_title = i18n("show_alerts.dropped_alerts"),
  icon = "fas fa-exclamation-triangle",
  i18n_description = formatDroppedAlerts,
}
