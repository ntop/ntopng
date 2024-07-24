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

local alert_ndpi_tls_suspicious_extension = classes.class(alert)

-- ##############################################

alert_ndpi_tls_suspicious_extension.meta = {
  alert_key = flow_alert_keys.flow_alert_ndpi_tls_suspicious_extension,
  i18n_title = "flow_checks_config.tls_suspicious_extension",
  icon = "fas fa-fw fa-info-circle",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.c_and_c,
      mitre_technique = mitre.technique.data_obfuscation,
      mitre_sub_technique = mitre.sub_technique.protocol_impersonation,
      mitre_id = "T1001.003"
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_tls_suspicious_extension:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

return alert_ndpi_tls_suspicious_extension

