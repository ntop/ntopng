--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"
local alert_creators = require "alert_creators"

-- #######################################################

local function formatDeviceDisconnectionAlert(ifid, alert, info)
  local device = info.device

  if not device or device == "" then
    device = alert.alert_entity_val
  end

  return(i18n("alert_messages.device_has_disconnected", {
    device = device,
    url = getMacUrl(alert.alert_entity_val),
  }))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_device_disconnection,
  i18n_title = "alerts_dashboard.device_disconnection",
  i18n_description = formatDeviceDisconnectionAlert,
  icon = "fas fa-sign-out",
  creator = alert_creators.createDeviceConnectionDisconnection,
}
