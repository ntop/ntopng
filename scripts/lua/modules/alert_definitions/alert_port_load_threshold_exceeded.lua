--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

local function snmpPortLoadThresholdFormatter(ifid, alert, info)
  if ntop.isPro() then require "snmp_utils" end

  local fmt = {
     device = info.device,
     port = info.interface_name or info.interface,
     url = snmpDeviceUrl(info.device),
     port_url = snmpIfaceUrl(info.device, info.interface),
     in_load = info.in_load,
     out_load = info.out_load,
     threshold = info.load_threshold,
  }

  return(i18n("alerts_dashboard.snmp_port_load_threshold_exceeded_message", fmt))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_port_load_threshold_exceeded,
  i18n_title = "alerts_dashboard.snmp_port_load_threshold_exceeded",
  i18n_description = snmpPortLoadThresholdFormatter,
  icon = "fas fa-exclamation",
}
