--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

local function formatDeviceConnectionAlert(ifid, alert, info)
  return(i18n("alert_messages.device_has_connected", {
    device = info.device,
    url = getMacUrl(alert.alert_entity_val),
  }))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_device_connection,
  i18n_title = "alerts_dashboard.device_connection",
  i18n_description = formatDeviceConnectionAlert,
  icon = "fas fa-sign-in",
}
