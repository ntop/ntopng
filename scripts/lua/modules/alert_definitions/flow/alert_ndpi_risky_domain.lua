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

local alert_ndpi_risky_domain = classes.class(alert)

-- ##############################################

alert_ndpi_risky_domain.meta = {
  alert_key = flow_alert_keys.flow_alert_ndpi_risky_domain,
  i18n_title = "flow_checks_config.risky_domain",
  icon = "fas fa-fw fa-info-circle",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_risky_domain:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

return alert_ndpi_risky_domain

