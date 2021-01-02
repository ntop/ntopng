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

local alert_influxdb_error = classes.class(alert)

-- ##############################################

alert_influxdb_error.meta = {
  alert_key = alert_keys.ntopng.alert_influxdb_error,
  i18n_title = "alerts_dashboard.influxdb_error",
  icon = "fas fa-database",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param last_error A string with the lastest influxdb error
-- @return A table with the alert built
function alert_influxdb_error:init(last_error)
   -- Call the paren constructor
   self.super:init()

   self.alert_type_params = {
    error_msg = last_error
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_influxdb_error.format(ifid, alert, alert_type_params)
  return(alert_type_params.error_msg)
end

-- #######################################################

return alert_influxdb_error
