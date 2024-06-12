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

local alert_unidirectional_traffic = classes.class(alert)

-- ##############################################

alert_unidirectional_traffic.meta = {
  alert_key = flow_alert_keys.flow_alert_ndpi_unidirectional_traffic,
  i18n_title = "flow_details.unidirectional_traffic",
  icon = "fas fa-fw fa-info-circle",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.c_and_c,
      mitre_tecnique = mitre.tecnique.web_service,
      mitre_sub_tecnique = mitre.sub_tecnique.one_way_communication,
      mitre_id = "T1102.003"
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_unidirectional_traffic:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

return alert_unidirectional_traffic

