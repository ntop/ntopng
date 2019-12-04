--
-- (C) 2019 - ntop.org
--

local function poolConnectionFormat(ifid, alert, info)
  return(i18n("alert_messages.host_pool_has_connected", {
    pool = info.pool,
    url = getHostPoolUrl(alert.alert_entity_val),
  }))
end

-- #######################################################

return {
  alert_id = 12,
  i18n_title = "alerts_dashboard.host_pool_connection",
  i18n_description = poolConnectionFormat,
  icon = "fa-sign-in",
}
