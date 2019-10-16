--
-- (C) 2019 - ntop.org
--

local function formatDeviceDisconnectionAlert(ifid, alert, info)
  return(i18n("alert_messages.device_has_disconnected", {
    device = info.device,
    url = getMacUrl(alert.alert_entity_val),
  }))
end

-- #######################################################

return {
  alert_id = 11,
  i18n_title = "alerts_dashboard.device_disconnection",
  i18n_description = formatDeviceDisconnectionAlert,
  icon = "fa-sign-out",
}
