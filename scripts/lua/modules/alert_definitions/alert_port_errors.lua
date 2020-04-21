--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

local function snmpInterfaceErrorsFormatter(ifid, alert, info)
  if ntop.isPro() then require "snmp_utils" end

  return(i18n("alerts_dashboard.snmp_port_errors_increased",
    {device = info.device,
     port = info.interface_name or info.interface,
     url = snmpDeviceUrl(info.device),
     port_url = snmpIfaceUrl(info.device, info.interface)}))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_port_errors,
  i18n_title = "alerts_dashboard.snmp_port_errors",
  i18n_description = snmpInterfaceErrorsFormatter,
  icon = "fas fa-exclamation",
}
