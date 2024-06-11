--
-- (C) 2019-24 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"

local format_utils = require "format_utils"
local json = require("dkjson")
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_remote_to_remote = classes.class(alert)

-- ##############################################

alert_remote_to_remote.meta = {
   alert_key = flow_alert_keys.flow_alert_remote_to_remote,
   i18n_title = "flow_checks_config.remote_to_remote",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_tactic = "mitre.tactic.lateral_movement",
   mitre_tecnique = "mitre.tecnique.session_hijacking",
   mitre_sub_tecnique = "mitre.sub_tecnique.rdp_hijacking",
   mitre_ID = "T1563.002",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_remote_to_remote:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_remote_to_remote.format(ifid, alert, alert_type_params)
   return
end

-- #######################################################

return alert_remote_to_remote
