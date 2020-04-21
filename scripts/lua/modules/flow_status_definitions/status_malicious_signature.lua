--
-- (C) 2019-20 - ntop.org
--

local status_keys = require "flow_keys"

local alert_consts = require("alert_consts")

-- #################################################################

local function formatMaliciousSignature(flowstatus_info)
  local res = i18n("alerts_dashboard.malicious_signature_detected")
  local cli_signature = flowstatus_info.cli_ja3_signature or
    (flowstatus_info.ja3_signature --[[ for compatibility with existing alerts ]])
  local srv_signature = flowstatus_info.srv_ja3_signature

  if not flowstatus_info then
    return res
  end

  if(cli_signature ~= nil) then
    res = i18n("flow_details.malicious_ja3_signature", {
      signature = cli_signature,
      url = "https://sslbl.abuse.ch/ja3-fingerprints/" .. cli_signature,
      icon = " <i class=\"fas fa-external-link-alt\"></i>",
      cli_or_srv = i18n("client"),
    })
  -- NOTE: JA3S only formatted for backward compatibility, see tls_malicious_signature.lua
  elseif(srv_signature ~= nil) then
    res = i18n("flow_details.malicious_ja3_signature", {
      signature = srv_signature,
      url = "https://sslbl.abuse.ch/ja3-fingerprints/" .. srv_signature,
      icon = " <i class=\"fas fa-external-link-alt\"></i>",
      cli_or_srv = i18n("server"),
    })
  end

  return res
end

-- #################################################################

return {
  status_key = status_keys.ntopng.status_malicious_signature,
  alert_severity = alert_consts.alert_severities.warning,
  alert_type = alert_consts.alert_types.alert_malicious_signature,
  i18n_title = "alerts_dashboard.malicious_signature_detected",
  i18n_description = formatMaliciousSignature
}
