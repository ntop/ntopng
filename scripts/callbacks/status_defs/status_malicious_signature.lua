--
-- (C) 2019 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

local function formatMaliciousSignature(status, flowstatus_info)
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
      icon = " <i class=\"fa fa-external-link\"></i>",
      cli_or_srv = i18n("client"),
    })
  elseif(srv_signature ~= nil) then
    res = i18n("flow_details.malicious_ja3_signature", {
      signature = srv_signature,
      url = "https://sslbl.abuse.ch/ja3-fingerprints/" .. srv_signature,
      icon = " <i class=\"fa fa-external-link\"></i>",
      cli_or_srv = i18n("server"),
    })
  end

  return res
end

-- #################################################################

return {
  status_id = 27,
  relevance = 80,
  prio = 690,
  alert_severity = alert_consts.alert_severities.warning,
  alert_type = alert_consts.alert_types.alert_malicious_signature,
  i18n_title = "alerts_dashboard.malicious_signature_detected",
  i18n_description = formatMaliciousSignature
}
