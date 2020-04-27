--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"
local alert_creators = require "alert_creators"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param device The a string with the name or ip address of the device that connected the network
-- @return A table with the alert built
local function createDeviceConnection(alert_severity, device)
  local built = {
    alert_severity = alert_severity,
    alert_type_params = {
       device = device,
    },
  }

  return built
end

-- #######################################################

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
  creator = alert_creators.createDeviceConnectionDisconnection,
}
