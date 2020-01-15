--
-- (C) 2019-20 - ntop.org
--

local function poolConnectionFormat(ifid, alert, info)
  return(i18n("alert_messages.host_pool_has_connected", {
    pool = info.pool,
    url = getHostPoolUrl(alert.alert_entity_val),
  }))
end

-- #######################################################

return {
  i18n_title = "alerts_dashboard.host_pool_connection",
  i18n_description = poolConnectionFormat,
  icon = "fas fa-sign-in",
}
