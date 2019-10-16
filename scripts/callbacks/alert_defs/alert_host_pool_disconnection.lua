--
-- (C) 2019 - ntop.org
--

local function poolDisconnectionFormat(ifid, alert, info)
  return(i18n("alert_messages.host_pool_has_disconnected", {
    pool = info.pool,
    url = getHostPoolUrl(alert.alert_entity_val),
  }))
end

-- #######################################################

return {
  alert_id = 13,
  i18n_title = "alerts_dashboard.host_pool_disconnection",
  i18n_description = poolDisconnectionFormat,
  icon = "fa-sign-out",
}
