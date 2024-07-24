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

local alert_ndpi_dns_invalid_characters = classes.class(alert)

-- ##############################################

alert_ndpi_dns_invalid_characters.meta = {
   alert_key  = flow_alert_keys.flow_alert_ndpi_invalid_characters,
   i18n_title = "flow_risk.ndpi_invalid_characters",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.credential_access,
      mitre_technique = mitre.technique.adversary_in_the_middle,
      mitre_id = "T1557"
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_dns_invalid_characters:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_ndpi_dns_invalid_characters.format(ifid, alert, alert_type_params)
   return i18n("flow_risk.ndpi_invalid_characters_alert_descr")
end

-- #######################################################

return alert_ndpi_dns_invalid_characters
