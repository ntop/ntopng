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

local alert_ndpi_error_code_detected = classes.class(alert)

-- ##############################################

alert_ndpi_error_code_detected.meta = {
   alert_key  = flow_alert_keys.flow_alert_ndpi_error_code_detected,
   i18n_title = "flow_risk.ndpi_error_code_detected",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.impact,
      mitre_technique = mitre.technique.endpoint_ddos,
      mitre_id = "T1499"
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_error_code_detected:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_ndpi_error_code_detected.format(ifid, alert, alert_type_params)
   return ""
end

-- #######################################################

return alert_ndpi_error_code_detected
