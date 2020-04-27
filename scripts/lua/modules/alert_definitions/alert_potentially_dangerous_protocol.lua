--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param tls_version A string indicating the TLS version detected, or nil when version is not available
-- @param tls_info A lua table with TLS info gererated calling `flow.getTLSInfo()`
-- @return A table with the alert built
local function buildPotentiallyDangerous(alert_severity, tls_version, tls_info)
   tls_info = tls_info or {}
   local server_cn = tls_info["protos.tls.server_names"] or ""
   local client_cn = tls_info["protos.tls.client_requested_server_name"] or ""

   local built = {
      alert_severity = alert_severity,
      alert_type_params = {
	 tls_version = tls_version,
	 ["tls_crt.cli"] = client_cn,
	 ["tls_crt.srv"] = server_cn,
	 ["tls_crt.notBefore"] = tls_info["protos.tls.notBefore"],
	 ["tls_crt.notAfter"] = tls_info["protos.tls.notAfter"],
	 ["tls_crt.now"] = os.time(),
	 ["cli_ja3_signature"] = tls_info["protos.tls.ja3.client_hash"],
      }
   }

   return built
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_potentially_dangerous_protocol,
  i18n_title = "alerts_dashboard.potentially_dangerous_protocol",
  i18n_description = "alert_messages.potentially_dangerous_protocol_description",
  icon = "fas fa-exclamation",
  builder = buildPotentiallyDangerous,
}
