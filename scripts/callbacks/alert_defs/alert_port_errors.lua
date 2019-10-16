--
-- (C) 2019 - ntop.org
--

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
  alert_id = 27,
  i18n_title = "alerts_dashboard.snmp_port_errors",
  i18n_description = snmpInterfaceErrorsFormatter,
  icon = "fa-exclamation",
}
