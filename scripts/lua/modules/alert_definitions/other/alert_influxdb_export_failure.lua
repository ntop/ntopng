--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_influxdb_export_failure = classes.class(alert)

-- ##############################################

alert_influxdb_export_failure.meta = {
   alert_key = other_alert_keys.alert_influxdb_export_failure,
   i18n_title = "alerts_dashboard.influxdb_export_failure",
   icon = "fas fa-fw fa-database",
entities = {},
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param influxdb The url used to export the points
-- @return A table with the alert built
function alert_influxdb_export_failure:init(influxdb)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      influxdb = influxdb,
   }
end

-- #######################################################

function alert_influxdb_export_failure.format(ifid, alert, alert_type_params)
   return i18n("alert_messages.influxdb_dropped_points")
end

-- #######################################################

return alert_influxdb_export_failure
