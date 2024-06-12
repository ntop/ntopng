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

local alert_ndpi_tls_not_carrying_https = classes.class(alert)

-- ##############################################

alert_ndpi_tls_not_carrying_https.meta = {
   alert_key  = flow_alert_keys.flow_alert_ndpi_tls_not_carrying_https,
   i18n_title = "flow_risk.ndpi_tls_not_carrying_https",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.c_and_c,
      mitre_tecnique = mitre.tecnique.data_obfuscation,
      mitre_sub_tecnique = mitre.sub_tecnique.protocol_impersonation,
      mitre_id = "T1001.003"
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_tls_not_carrying_https:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_ndpi_tls_not_carrying_https.format(ifid, alert, alert_type_params)
   return
end

-- #######################################################

return alert_ndpi_tls_not_carrying_https
