--
-- (C) 2019 - ntop.org
--

local function formatDeviceConnectionAlert(ifid, alert, info)
  return(i18n("alert_messages.device_has_connected", {
    device = info.device,
    url = getMacUrl(alert.alert_entity_val),
  }))
end

-- #######################################################

return {
  alert_id = 10,
  i18n_title = "alerts_dashboard.device_connection",
  i18n_description = formatDeviceConnectionAlert,
  icon = "fa-sign-in",
}
