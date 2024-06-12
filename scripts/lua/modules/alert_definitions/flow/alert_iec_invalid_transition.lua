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
-- Import Mitre Att&ck utils
local mitre = require "mitre_utils"

-- ##############################################

local alert_iec_invalid_transition = classes.class(alert)

-- ##############################################

alert_iec_invalid_transition.meta = {
   alert_key = flow_alert_keys.flow_alert_iec_invalid_transition,
   i18n_title = "flow_checks.iec104_title",
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
function alert_iec_invalid_transition:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_iec_invalid_transition.format(ifid, alert, alert_type_params)
   local from = iec104_typeids2str(alert_type_params.from) or alert_type_params.from or i18n('unknown')
   local to = iec104_typeids2str(alert_type_params.to) or alert_type_params.to or i18n('unknown')

   local rsp = "[TypeId: ".. from .. " -> ".. to .. "]"

   -- tprint(rsp)
   
   return(rsp)
end

-- #######################################################

return alert_iec_invalid_transition
