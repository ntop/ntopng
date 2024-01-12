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

local alert_ndpi_malicious_sha1_certificate = classes.class(alert)

-- ##############################################

alert_ndpi_malicious_sha1_certificate.meta = {
  alert_key = flow_alert_keys.flow_alert_ndpi_malicious_sha1_certificate,
  i18n_title = "flow_checks_config.malicious_sha1_certificate",
  icon = "fas fa-fw fa-info-circle",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_malicious_sha1_certificate:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

return alert_ndpi_malicious_sha1_certificate

