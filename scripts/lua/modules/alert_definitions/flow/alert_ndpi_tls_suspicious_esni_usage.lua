--
-- (C) 2019-24 - ntop.org
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

local alert_ndpi_tls_suspicious_esni_usage = classes.class(alert)

-- ##############################################

alert_ndpi_tls_suspicious_esni_usage.meta = {
   alert_key  = flow_alert_keys.flow_alert_ndpi_tls_suspicious_esni_usage,
   i18n_title = "alerts_dashboard.ndpi_tls_suspicious_esni_usage_title",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.c_and_c,
      mitre_technique = mitre.technique.proxy,
      mitre_sub_technique = mitre.sub_technique.domain_fronting,
      mitre_id = "T1090.004"
   },

   has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_tls_suspicious_esni_usage:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_ndpi_tls_suspicious_esni_usage.format(ifid, alert, alert_type_params)
   return
end

-- #######################################################

return alert_ndpi_tls_suspicious_esni_usage
