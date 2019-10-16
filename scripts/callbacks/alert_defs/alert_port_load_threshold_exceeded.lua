--
-- (C) 2019 - ntop.org
--

local function snmpPortLoadThresholdFormatter(ifid, alert, info)
  if ntop.isPro() then require "snmp_utils" end

  return(i18n("alerts_dashboard.snmp_port_load_threshold_exceeded_message",
    {device = info.device,
     port = info.interface_name or info.interface,
     url = snmpDeviceUrl(info.device),
     port_url = snmpIfaceUrl(info.device, info.interface),
     port_load = info.interface_load,
     direction = ternary(info.interface_load, "RX", "TX")}))
end

-- #######################################################

return {
  alert_id = 38,
  i18n_title = "alerts_dashboard.snmp_port_load_threshold_exceeded",
  i18n_description = snmpPortLoadThresholdFormatter,
  icon = "fa-exclamation",
}
