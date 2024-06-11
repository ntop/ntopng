--
-- (C) 2019-24 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_ndpi_tls_missing_sni = classes.class(alert)

-- ##############################################

alert_ndpi_tls_missing_sni.meta = {
   alert_key  = flow_alert_keys.flow_alert_ndpi_tls_missing_sni,
   i18n_title = "flow_risk.ndpi_tls_missing_sni",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_tactic = "mitre.tactic.c_and_c",
   mitre_tecnique = "mitre.tecnique.proxy",
   mitre_ID = "T1090",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_tls_missing_sni:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_ndpi_tls_missing_sni.format(ifid, alert, alert_type_params)
   return
end

-- #######################################################

return alert_ndpi_tls_missing_sni
