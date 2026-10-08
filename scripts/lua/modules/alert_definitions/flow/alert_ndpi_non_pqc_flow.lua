--
-- (C) 2019-26 - ntop.org
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

local alert_ndpi_non_pqc_flow = classes.class(alert)

-- ##############################################

alert_ndpi_non_pqc_flow.meta = {
   alert_key  = flow_alert_keys.flow_alert_ndpi_non_pqc_flow,
   i18n_title = "flow_risk.ndpi_non_pqc_flow",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.discovery,
      mitre_technique = mitre.technique.network_sniffing,
      mitre_id = "T1040"
   },

   has_victim = true,
   has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_non_pqc_flow:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_ndpi_non_pqc_flow.format(ifid, alert, alert_type_params)
   return
end

-- #######################################################

return alert_ndpi_non_pqc_flow
