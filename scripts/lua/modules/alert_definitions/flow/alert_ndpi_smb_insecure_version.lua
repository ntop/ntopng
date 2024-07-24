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

local alert_ndpi_smb_insecure_version = classes.class(alert)

-- ##############################################

alert_ndpi_smb_insecure_version.meta = {
   alert_key  = flow_alert_keys.flow_alert_ndpi_smb_insecure_version,
   i18n_title = "flow_risk.ndpi_smb_insecure_version",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.lateral_movement,
      mitre_technique = mitre.technique.remote_services,
      mitre_sub_technique = mitre.sub_technique.smb_windows_admin_share,
      mitre_id = "T1021.002"
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_smb_insecure_version:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_ndpi_smb_insecure_version.format(ifid, alert, alert_type_params)
   return
end

-- #######################################################

return alert_ndpi_smb_insecure_version
