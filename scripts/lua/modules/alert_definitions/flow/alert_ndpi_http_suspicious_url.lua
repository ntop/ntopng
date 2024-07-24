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

local alert_ndpi_http_suspicious_url = classes.class(alert)

-- ##############################################

alert_ndpi_http_suspicious_url.meta = {
   alert_key  = flow_alert_keys.flow_alert_ndpi_http_suspicious_url,
   i18n_title = "flow_risk.ndpi_http_suspicious_url",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.initial_access,
      mitre_technique = mitre.technique.drive_by_compr,
      mitre_id = "T1189"
   },

   has_victim = true,
   has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_http_suspicious_url:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_ndpi_http_suspicious_url.format(ifid, alert, alert_type_params)
   return i18n('alerts_dashboard.ndpi_http_suspicious_url_descr')
end

-- #######################################################

return alert_ndpi_http_suspicious_url
