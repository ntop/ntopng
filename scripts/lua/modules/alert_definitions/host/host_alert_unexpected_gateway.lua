--
-- (C) 2019-24 - ntop.org
--

-- ##############################################

local host_alert_keys = require "host_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
-- Import Mitre Att&ck utils
local mitre = require "mitre_utils"

-- ##############################################

local host_alert_unexpected_gateway = classes.class(alert)

-- ##############################################

host_alert_unexpected_gateway.meta = {
   alert_key = host_alert_keys.host_alert_unexpected_gateway,
   i18n_title = "flow_checks.unexpected_gateway_title",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.defense_evasion,
      mitre_technique = mitre.technique.rogue_domain_controller,
      mitre_id = "T1207"
   },

   has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_flow_param The first alert param
-- @param another_flow_param The second alert param
-- @return A table with the alert built
function host_alert_unexpected_gateway:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_unexpected_gateway.format(ifid, alert, alert_type_params)
    return(i18n("flow_alerts_explorer.status_unexpected_gateway_description", { server=alert_type_params.server_ip} ))
end

-- #######################################################

return host_alert_unexpected_gateway
