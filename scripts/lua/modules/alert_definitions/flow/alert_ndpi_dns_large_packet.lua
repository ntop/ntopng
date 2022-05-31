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

local alert_ndpi_dns_large_packet = classes.class(alert)

-- ##############################################

alert_ndpi_dns_large_packet.meta = {
   alert_key  = flow_alert_keys.flow_alert_ndpi_dns_large_packet,
   i18n_title = "flow_risk.ndpi_suspicious_entropy",
   icon = "fas fa-fw fa-exclamation",

   has_victim = true,
   has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_dns_large_packet:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_ndpi_dns_large_packet.format(ifid, alert, alert_type_params)
   return ""
end

-- #######################################################

return alert_ndpi_dns_large_packet
