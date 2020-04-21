--
-- (C) 2020 - ntop.org
--

local status_keys = require "flow_keys"

local alert_consts = require("alert_consts")

-- #################################################################

local function formatTLSCertificateExpired(flowstatus_info)
   if not flowstatus_info then
      return i18n("flow_details.tls_certificate_expired")
   end

   local crts = {}
   crts[#crts + 1] = formatEpoch(flowstatus_info["tls_crt.notBefore"])
   crts[#crts + 1] = formatEpoch(flowstatus_info["tls_crt.notAfter"])

   return string.format("%s [%s]", i18n("flow_details.tls_certificate_expired"), table.concat(crts, " - "))
end

-- #################################################################

return {
  status_key = status_keys.ntopng.status_tls_certificate_expired,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_potentially_dangerous_protocol,
  i18n_title = "flow_details.tls_certificate_expired",
  i18n_description = formatTLSCertificateExpired
}
