--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

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
}
