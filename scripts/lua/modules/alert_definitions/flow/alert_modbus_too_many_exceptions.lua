--
-- (C) 2019-24 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
local json = require "dkjson"
local format_utils = require "format_utils"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
-- Import Mitre Att&ck utils
local mitre = require "mitre_utils"

-- ##############################################

local alert_modbus_too_many_exceptions = classes.class(alert)

-- ##############################################

alert_modbus_too_many_exceptions.meta = {
   alert_key = flow_alert_keys.flow_alert_modbus_too_many_exceptions,
   i18n_title = "flow_checks.modbus_too_many_exceptions",
   icon = "fas fa-fw fa-subway",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.impact,
      mitre_tecnique = mitre.tecnique.data_manipulation,
      mitre_id = "T1565"
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param last_error A string with the lastest influxdb error
-- @return A table with the alert built
function alert_modbus_too_many_exceptions:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_modbus_too_many_exceptions.format(ifid, alert, alert_type_params)
   local rsp = alert_type_params.num_exceptions .. " Exceptions"

   -- tprint(alert_type_params)
   
   return(rsp)
end

-- #######################################################

return alert_modbus_too_many_exceptions
