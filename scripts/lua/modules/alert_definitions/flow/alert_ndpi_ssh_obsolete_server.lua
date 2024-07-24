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

local alert_ndpi_ssh_obsolete_server = classes.class(alert)

-- ##############################################

alert_ndpi_ssh_obsolete_server.meta = {
   alert_key  = flow_alert_keys.flow_alert_ndpi_ssh_obsolete_server,
   i18n_title = "alerts_dashboard.ndpi_ssh_obsolete_server_title",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.execution,
      mitre_technique = mitre.technique.exploitation_client_exec,
      mitre_id = "T1203"
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_ssh_obsolete_server:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_ndpi_ssh_obsolete_server.format(ifid, alert, alert_type_params)
   if alert_type_params and alert_type_params.proto and alert_type_params.proto.ssh then   
      local server_signature = alert_type_params.proto.ssh.server_signature
      return i18n("flow_risk.ndpi_ssh_obsolete_server_version_or_cipher_signature", { signature = server_signature }) 
   end
   return i18n("flow_risk.ndpi_ssh_obsolete_server_version_or_cipher")
end

-- #######################################################

return alert_ndpi_ssh_obsolete_server
