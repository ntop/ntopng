--
-- (C) 2019-20 - ntop.org
--

local status_keys = require "flow_keys"

local alert_consts = require("alert_consts")

-- #################################################################

local function formatTLSCertificateMismatch(flowstatus_info)
   if not flowstatus_info then
      return i18n("flow_details.tls_certificate_mismatch")
   end

   local crts = {}
   if not isEmptyString(flowstatus_info["tls_crt.cli"]) then
      crts[#crts + 1] = string.format("[%s: %s]", i18n("flow_details.client_requested"), flowstatus_info["tls_crt.cli"])
   end

   if not isEmptyString(flowstatus_info["tls_crt.srv"]) then
      crts[#crts + 1] = string.format("[%s: %s]", i18n("flow_details.tls_server_names"), flowstatus_info["tls_crt.srv"])
   end

   return string.format("%s %s", i18n("flow_details.tls_certificate_mismatch"), table.concat(crts, " "))
end

-- #################################################################

return {
  status_key = status_keys.ntopng.status_tls_certificate_mismatch,
  alert_type = alert_consts.alert_types.alert_potentially_dangerous_protocol,
  i18n_title = "flow_details.tls_certificate_mismatch",
  i18n_description = formatTLSCertificateMismatch
}
