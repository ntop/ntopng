--
-- (C) 2019-20 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
local status_keys = require "status_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_data_exfiltration = classes.class(alert)

-- ##############################################

alert_data_exfiltration.meta = {
   status_key = status_keys.ntopng.status_data_exfiltration,
   alert_key = alert_keys.ntopng.alert_data_exfiltration,
   i18n_title = "flow_details.data_exfiltration",
   icon = "fas fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_data_exfiltration:init()
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      -- No params
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_data_exfiltration.format(ifid, alert, alert_type_params)
   return i18n("flow_details.data_exfiltration")
end

-- #######################################################

return alert_data_exfiltration
