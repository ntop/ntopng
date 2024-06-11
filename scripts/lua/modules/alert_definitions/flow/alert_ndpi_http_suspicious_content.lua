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

local alert_http_suspicious_content = classes.class(alert)

-- ##############################################

alert_http_suspicious_content.meta = {
   alert_key  = flow_alert_keys.flow_alert_ndpi_http_suspicious_content,
   i18n_title = "flow_risk.ndpi_http_suspicious_content",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_tactic = "mitre.tactic.defense_evasion",
   mitre_tecnique = "mitre.tecnique.obfuscated_files_info",
   mitre_ID = "T1027",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_http_suspicious_content:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_http_suspicious_content.format(ifid, alert, alert_type_params)
  return ""
end

-- #######################################################

return alert_http_suspicious_content
