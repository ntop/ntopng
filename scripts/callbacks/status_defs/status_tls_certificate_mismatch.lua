--
-- (C) 2019 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

local function formatTLSCertificateMismatch(status, flowstatus_info)
   if not flowstatus_info then
      return i18n("flow_details.tls_certificate_mismatch")
   end

   local crts = {}
   if not isEmptyString(flowstatus_info["tls_crt.cli"]) then
      crts[#crts + 1] = string.format("[%s: %s]", i18n("flow_details.tls_client_certificate"), flowstatus_info["tls_crt.cli"])
   end

   if not isEmptyString(flowstatus_info["tls_crt.srv"]) then
      crts[#crts + 1] = string.format("[%s: %s]", i18n("flow_details.tls_server_certificate"), flowstatus_info["tls_crt.srv"])
   end

   return string.format("%s %s", i18n("flow_details.tls_certificate_mismatch"), table.concat(crts, " "))
end

-- #################################################################

return {
  status_id = 10,
  relevance = 50,
  prio = 360,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_potentially_dangerous_protocol,
  i18n_title = "flow_details.tls_certificate_mismatch",
  i18n_description = formatTLSCertificateMismatch
}
