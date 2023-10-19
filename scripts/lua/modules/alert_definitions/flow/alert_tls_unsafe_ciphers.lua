--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_tls_unsafe_ciphers = classes.class(alert)

-- ##############################################

alert_tls_unsafe_ciphers.meta = {
   alert_key = flow_alert_keys.flow_alert_tls_unsafe_ciphers,
   i18n_title = "flow_details.tls_unsafe_ciphers",
   icon = "fas fa-fw fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_tls_unsafe_ciphers:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_tls_unsafe_ciphers.format(ifid, alert, alert_type_params)
   return i18n("flow_risk.ndpi_tls_weak_cipher")
end

-- #######################################################

return alert_tls_unsafe_ciphers
