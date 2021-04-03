--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_udp_unidirectional = classes.class(alert)

-- ##############################################

alert_udp_unidirectional.meta = {
  alert_key = flow_alert_keys.flow_alert_udp_unidirectional,
  i18n_title = "flow_details.udp_unidirectional",
  icon = "fas fa-info-circle",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_udp_unidirectional:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

return alert_udp_unidirectional

