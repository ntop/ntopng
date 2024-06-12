--
-- (C) 2019-24 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
-- Import Mitre Att&ck utils
local mitre = require "mitre_utils"

-- ##############################################

local alert_known_proto_on_non_std_port = classes.class(alert)

-- ##############################################

alert_known_proto_on_non_std_port.meta = {   
   alert_key = flow_alert_keys.flow_alert_known_proto_on_non_std_port,
   i18n_title = "alerts_dashboard.known_proto_on_non_std_port",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.c_and_c,
      mitre_tecnique = mitre.tecnique.nont_std_port,
      mitre_id = "T1571"
   },

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
   return i18n('flow_risk.ndpi_known_proto_on_non_stand_port_descr')
end

-- #######################################################

return alert_known_proto_on_non_std_port
