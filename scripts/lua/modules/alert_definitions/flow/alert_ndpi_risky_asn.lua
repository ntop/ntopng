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

local alert_ndpi_risky_asn = classes.class(alert)

-- ##############################################

alert_ndpi_risky_asn.meta = {
  alert_key = flow_alert_keys.flow_alert_ndpi_risky_asn,
  i18n_title = "flow_checks_config.risky_asn",
  icon = "fas fa-fw fa-info-circle",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_risky_asn:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

return alert_ndpi_risky_asn

