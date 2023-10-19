--
-- (C) 2019-23 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
local json = require "dkjson"
local format_utils = require "format_utils"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"


-- ##############################################

local alert_modbus_invalid_transition = classes.class(alert)

-- ##############################################

alert_modbus_invalid_transition.meta = {
   alert_key = flow_alert_keys.flow_alert_modbus_invalid_transition,
   i18n_title = "flow_checks.modbus_invalid_transition",
   icon = "fas fa-fw fa-subway",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param last_error A string with the lastest influxdb error
-- @return A table with the alert built
function alert_modbus_invalid_transition:init()
   -- Call the parent constructor
   self.super:init()
end

-- ##############################################

local function function_code_to_string(function_id)
  if(function_id == 1) then    return("Read Coils (" .. function_id .. ")") end
  if(function_id == 2) then    return("Read Discrete Inputs (" .. function_id .. ")") end
  if(function_id == 3) then    return("Read Holding Registers (" .. function_id .. ")") end
  if(function_id == 4) then    return("Read Input Registers (" .. function_id .. ")") end
  if(function_id == 5) then    return("Write Single Coil (" .. function_id .. ")") end
  if(function_id == 6) then    return("Write Single Register (" .. function_id .. ")") end
  if(function_id == 7) then    return("Read Exception Status (" .. function_id .. ")") end
  if(function_id == 8) then    return("Diagnostics (" .. function_id .. ")") end
  if(function_id == 11) then   return("Get Comm. Event Counters (" .. function_id .. ")") end
  if(function_id == 12) then   return("Get Comm. Event Log (" .. function_id .. ")") end
  if(function_id == 15) then   return("Write Multiple Coils (" .. function_id .. ")") end
  if(function_id == 16) then   return("Write Multiple Registers (" .. function_id .. ")") end
  if(function_id == 17) then   return("Report Slave ID (" .. function_id .. ")") end
  if(function_id == 20) then   return("Read File Record (" .. function_id .. ")") end
  if(function_id == 21) then   return("Write File Record (" .. function_id .. ")") end
  if(function_id == 22) then   return("Mask Write Register (" .. function_id .. ")") end
  if(function_id == 23) then   return("Read Write Register (" .. function_id .. ")") end
  if(function_id == 24) then   return("Read FIFO Queue (" .. function_id .. ")") end
  if(function_id == 43) then   return("Encapsulated Interface Transport (" .. function_id .. ")") end
  if(function_id == 90) then   return("Unity (Schneider) (" .. function_id .. ")") end

   return(function_id)
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_modbus_invalid_transition.format(ifid, alert, alert_type_params)
   local from = function_code_to_string(alert_type_params.from) or alert_type_params.from or i18n('unknown')
   local to   = function_code_to_string(alert_type_params.to) or alert_type_params.to or i18n('unknown')

   local rsp = from .. " -> ".. to 

   -- tprint(alert_type_params)
   
   return(rsp)
end

-- #######################################################

return alert_modbus_invalid_transition
