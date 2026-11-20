--
-- (C) 2019-26 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
-- Import Mitre Att&ck utils
local mitre = require "mitre_utils"

-- ##############################################

local alert_tls_certificate_expired = classes.class(alert)

-- ##############################################

alert_tls_certificate_expired.meta = {
   alert_key = flow_alert_keys.flow_alert_tls_certificate_expired,
   i18n_title = "flow_details.tls_certificate_expired",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.initial_access,
      mitre_technique = mitre.technique.valid_accounts,
      mitre_id = "T1078"
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param tls_info A lua table with TLS info gererated calling `flow.getTLSInfo()`
-- @return A table with the alert built
function alert_tls_certificate_expired:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_tls_certificate_expired.format(ifid, alert, alert_type_params)
   if not alert_type_params then
      return
   end

   local tls_info = (alert_type_params.proto or {}).tls or {}

   if tls_info.notBefore and tls_info.notAfter then
      local params = {
         notBefore = formatEpoch(tls_info.notBefore),
         notAfter = formatEpoch(tls_info.notAfter)
      }

      if tonumber(alert.tstamp) and tonumber(alert.tstamp) < tls_info.notBefore then
         return i18n("flow_risk.ndpi_tls_certificate_not_yet_valid", params)
      end

      return i18n("flow_risk.ndpi_tls_certificate_expired", params)
   end

   -- Old alerts without TLS info: use the validity reported by nDPI
   local alert_risk = ntop.getFlowAlertRisk(tonumber(alert.alert_id))
   local validity = alert_type_params.flow_risk_info and alert_type_params.flow_risk_info[tostring(alert_risk)]

   if not isEmptyString(validity) then
      return i18n("flow_risk.ndpi_tls_certificate_expired_validity", { validity = validity })
   end

   return i18n("flow_risk.ndpi_tls_certificate_expired_generic")
end

-- #######################################################

return alert_tls_certificate_expired
