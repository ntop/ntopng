--
-- (C) 2019-24 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

local format_utils = require "format_utils"

-- ##############################################

local alert_tcp_flow_reset = classes.class(alert)

-- ##############################################

alert_tcp_flow_reset.meta = {
   alert_key = flow_alert_keys.flow_alert_tcp_flow_reset,
   i18n_title = "flow_checks_config.flow_reset_title",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_tactic = "mitre.tactic.impact",
   mitre_tecnique = "mitre.tecnique.endpoint_ddos",
   mitre_ID = "T1499",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_flow_param The first alert param
-- @param another_flow_param The second alert param
-- @return A table with the alert built
function alert_tcp_flow_reset:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_tcp_flow_reset.format(ifid, alert, alert_type_params)
   return i18n("alert_messages.flow_reset")

end

-- #######################################################

return alert_tcp_flow_reset
