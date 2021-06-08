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

local alert_known_proto_on_non_std_port = classes.class(alert)

-- ##############################################

alert_known_proto_on_non_std_port.meta = {   
   alert_key = flow_alert_keys.flow_alert_known_proto_on_non_std_port,
   i18n_title = "alerts_dashboard.known_proto_on_non_std_port",
   icon = "fas fa-fw fa-exclamation",

   has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param info A lua table containing flow information obtained with `flow.getInfo()`
-- @return A table with the alert built
function alert_known_proto_on_non_std_port:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_known_proto_on_non_std_port.format(ifid, alert, alert_type_params)
   return
end

-- #######################################################

return alert_known_proto_on_non_std_port
