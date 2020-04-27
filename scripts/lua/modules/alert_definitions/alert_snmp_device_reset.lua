--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param alert_granularity A granularity as defined in `alert_consts.alerts_granularities`
-- @param device_ip A string with the ip address of the snmp device
-- @return A table with the alert built
local function createDeviceReset(alert_severity, alert_granularity, device_ip)
   local built = {
      alert_severity = alert_severity,
      alert_granularity = alert_granularity,
      alert_type_params = {
	 device = device_ip,
      },
   }

   return built
end

-- #######################################################

local function snmpDeviceResetFormatter(ifid, alert, info)
  if ntop.isPro() then require "snmp_utils" end

  return(i18n("alerts_dashboard.alert_snmp_device_reset_description",
    {device = info.device,
     url = snmpDeviceUrl(info.device)}))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_snmp_device_reset,
  i18n_title = "alerts_dashboard.alert_snmp_device_reset_title",
  i18n_description = snmpDeviceResetFormatter,
  icon = "fas fa-power-off",
  creator = createDeviceReset,
}
