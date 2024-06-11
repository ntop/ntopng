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

local alert_ndpi_punicody_idn = classes.class(alert)

-- ##############################################

alert_ndpi_punicody_idn.meta = {
   alert_key  = flow_alert_keys.flow_alert_ndpi_punicody_idn,
   i18n_title = "flow_risk.ndpi_punicody_idn",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_tactic = "mitre.tactic.initial_access",
   mitre_tecnique = "mitre.tecnique.phishing",
   mitre_sub_tecnique = "mitre.sub_tecnique.spearphishing_link",
   mitre_ID = "T1566.002",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_punicody_idn:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_ndpi_punicody_idn.format(ifid, alert, alert_type_params)
   return ""
end

-- #######################################################

return alert_ndpi_punicody_idn
