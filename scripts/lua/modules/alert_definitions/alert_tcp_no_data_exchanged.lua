--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_tcp_no_data_exchanged = classes.class(alert)

-- ##############################################

alert_tcp_no_data_exchanged.meta = {
   alert_key = alert_keys.ntopng.alert_tcp_no_data_exchanged,
   i18n_title = "tcp_no_data_exchanged.alert_tcp_no_data_exchanged_title",
   icon = "fas fa-arrow-circle-up",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_tcp_no_data_exchanged:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_tcp_no_data_exchanged.format(ifid, alert, alert_type_params)
   return i18n("tcp_no_data_exchanged.alert_tcp_no_data_exchanged_description")
end

-- #######################################################

return alert_tcp_no_data_exchanged
