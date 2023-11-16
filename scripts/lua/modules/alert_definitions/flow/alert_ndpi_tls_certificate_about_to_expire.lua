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

local alert_ndpi_tls_certificate_about_to_expire = classes.class(alert)

-- ##############################################

alert_ndpi_tls_certificate_about_to_expire.meta = {
   alert_key  = flow_alert_keys.flow_alert_ndpi_tls_certificate_about_to_expire,
   i18n_title = "flow_risk.ndpi_tls_certificate_about_to_expire",
   icon = "fas fa-fw fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_tls_certificate_about_to_expire:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_ndpi_tls_certificate_about_to_expire.format(ifid, alert, alert_type_params)
   return ""
end

-- #######################################################

return alert_ndpi_tls_certificate_about_to_expire
