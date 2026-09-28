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

local alert_s7comm_invalid_transition = classes.class(alert)

-- ##############################################

alert_s7comm_invalid_transition.meta = {
   alert_key = flow_alert_keys.flow_alert_s7comm_invalid_transition,
   i18n_title = "flow_checks.s7comm_invalid_transition",
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
function alert_s7comm_invalid_transition:init()
   -- Call the parent constructor
   self.super:init()
end

-- ##############################################

-- S7Comm function codes
-- NOTE: keep in sync with function_codes in pro/scripts/lua/modules/s7comm_utils.lua
local function_code_names = {
  [0x00] = "CPU services",
  [0x01] = "Mode transition",
  [0x04] = "Read Var",
  [0x05] = "Write Var",
  [0x1a] = "Request download",
  [0x1b] = "Download block",
  [0x1c] = "Download ended",
  [0x1d] = "Start upload",
  [0x1e] = "Upload",
  [0x1f] = "End upload",
  [0x28] = "PI-Service",
  [0x29] = "PLC Stop",
  [0xf0] = "Setup communication",
}

local function function_code_to_string(function_id)
  local name = function_code_names[tonumber(function_id or "")]

  if(name == nil) then return(function_id) end

  return(name .. " (" .. function_id .. ")")
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_s7comm_invalid_transition.format(ifid, alert, alert_type_params)
   local from = function_code_to_string(alert_type_params.from) or alert_type_params.from or i18n('unknown')
   local to   = function_code_to_string(alert_type_params.to) or alert_type_params.to or i18n('unknown')

   local rsp = from .. " -> ".. to

   -- tprint(alert_type_params)

   return(rsp)
end

-- #######################################################

return alert_s7comm_invalid_transition
