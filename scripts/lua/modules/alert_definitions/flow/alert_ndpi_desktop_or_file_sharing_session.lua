--
-- (C) 2019-24 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_ndpi_desktop_or_file_sharing_session = classes.class(alert)

-- ##############################################

alert_ndpi_desktop_or_file_sharing_session.meta = {
  alert_key = flow_alert_keys.flow_alert_ndpi_desktop_or_file_sharing_session,
  i18n_title = "flow_checks_config.desktop_or_file_sharing_session",
  icon = "fas fa-fw fa-info-circle",

   -- Mitre Att&ck Matrix values
   mitre_tactic = "mitre.tactic.lateral_movement",
   mitre_tecnique = "mitre.tecnique.lateral_tool_transfer",
   mitre_ID = "T1570",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_desktop_or_file_sharing_session:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

return alert_ndpi_desktop_or_file_sharing_session

