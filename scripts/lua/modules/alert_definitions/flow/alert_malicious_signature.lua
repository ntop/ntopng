--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_malicious_signature = classes.class(alert)

-- ##############################################

alert_malicious_signature.meta = {
   alert_key = flow_alert_keys.flow_alert_malicious_signature,
   i18n_title = "flow_risk.malicious_signature_detected",
   icon = "fas fa-fw fa-ban",

   has_victim = true,
   has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_malicious_signature:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_malicious_signature.format(ifid, alert, alert_type_params)
   return(i18n("alerts_dashboard.malicious_signature_detected", {
		  ja3_hash = alert_type_params["ja3_client_hash"]
   }))
end

-- #######################################################

return alert_malicious_signature
