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

local alert_unidirectional_traffic = classes.class(alert)

-- ##############################################

alert_unidirectional_traffic.meta = {
  alert_key = flow_alert_keys.flow_alert_ndpi_unidirectional_traffic,
  i18n_title = "flow_details.unidirectional_traffic",
  icon = "fas fa-fw fa-info-circle",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_unidirectional_traffic:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

return alert_unidirectional_traffic

