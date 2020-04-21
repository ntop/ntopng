--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

local function formatNewDeviceConnectionAlert(ifid, alert, info)
  return(i18n("alert_messages.a_new_device_has_connected", {
    device = info.device,
    url = getMacUrl(alert.alert_entity_val),
  }))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_new_device,
  i18n_title = "alerts_dashboard.new_device",
  i18n_description = formatNewDeviceConnectionAlert,
  icon = "fas fa-asterisk",
}
