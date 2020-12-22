--
-- (C) 2020 - ntop.org
--

local status_keys = require "flow_keys"

local alert_consts = require("alert_consts")

-- #################################################################

local function formatTLSCertificateSelfsigned(flowstatus_info)
   if not flowstatus_info then
      return i18n("flow_details.tls_certificate_selfsigned")
   end

   local crts = {}
   crts[#crts + 1] = flowstatus_info["tls_crt.issuerDN"]

   return string.format("%s [Issuer/Subject: %s]", i18n("flow_details.tls_certificate_selfsigned"), table.concat(crts, " - "))
end

-- #################################################################

return {
  status_key = status_keys.ntopng.status_tls_certificate_selfsigned,
  -- When a self-signed certificate il found an alert of type alert_potentially_dangerous_protocol
  -- is generated (see alert_potentially_dangerous_protocol.lua)
  alert_type = alert_consts.alert_types.alert_potentially_dangerous_protocol,
  i18n_title = "flow_details.tls_certificate_selfsigned",
  i18n_description = formatTLSCertificateSelfsigned
}
