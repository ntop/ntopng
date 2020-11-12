--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param cli_devtype A string with the device type of the client
-- @param srv_devtype A string with the device type of the server
-- @param devproto_forbidden_peer A string with the forbidden peer, one of 'cli' or 'srv'
-- @param devproto_forbidden_id The nDPI ID of the forbidden application protocol
-- @return A table with the alert built
local function createDeviceProtocolNotAllowed(cli_devtype, srv_devtype, devproto_forbidden_peer, devproto_forbidden_id)
   local built = {
      alert_type_params = {
	 ["cli.devtype"] = cli_devtype,
	 ["srv.devtype"] = srv_devtype,
	 devproto_forbidden_peer = devproto_forbidden_peer,
	 devproto_forbidden_id = devproto_forbidden_id
      }
   }

   return built
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_device_protocol_not_allowed,
  i18n_title = "alerts_dashboard.suspicious_device_protocol",
  icon = "fas fa-exclamation",
  creator = createDeviceProtocolNotAllowed
}
