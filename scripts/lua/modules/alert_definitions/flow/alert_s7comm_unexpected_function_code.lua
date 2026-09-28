--
-- (C) 2019-26 - ntop.org
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

local alert_s7comm_unexpected_function_code = classes.class(alert)

-- ##############################################

alert_s7comm_unexpected_function_code.meta = {
   alert_key = flow_alert_keys.flow_alert_s7comm_unexpected_function_code,
   i18n_title = "flow_checks.s7comm_unexpected_function_code_title",
   icon = "fas fa-fw fa-industry",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.impact,
      mitre_technique = mitre.technique.data_manipulation,
      mitre_id = "T1565"
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param last_error A string with the lastest influxdb error
-- @return A table with the alert built
function alert_s7comm_unexpected_function_code:init()
   -- Call the parent constructor
   self.super:init()
end

-- ##############################################

local function function_code_to_string(function_id)
  -- S7Comm function codes
  if(function_id == 0x04) then return("Read Var (" .. function_id .. ")") end
  if(function_id == 0x05) then return("Write Var (" .. function_id .. ")") end
  if(function_id == 0xf0) then return("Setup Communication (" .. function_id .. ")") end
  if(function_id == 0x00) then return("CPU Services (" .. function_id .. ")") end
  if(function_id == 0x29) then return("PLC Control (" .. function_id .. ")") end
  if(function_id == 0x28) then return("PLC Stop (" .. function_id .. ")") end

  return(function_id)
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_s7comm_unexpected_function_code.format(ifid, alert, alert_type_params)
   local rsp = "Function Code '".. function_code_to_string(alert_type_params.function_code) .. "' detected"

   -- tprint(alert_type_params)

   return(rsp)
end

-- #######################################################

return alert_s7comm_unexpected_function_code
