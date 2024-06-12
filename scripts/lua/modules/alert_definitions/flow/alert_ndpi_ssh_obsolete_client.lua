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

local alert_ndpi_ssh_obsolete_client = classes.class(alert)

-- ##############################################

alert_ndpi_ssh_obsolete_client.meta = {
   alert_key  = flow_alert_keys.flow_alert_ndpi_ssh_obsolete_client,
   i18n_title = "flow_risk.ndpi_ssh_obsolete_client_version_or_cipher",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.lateral_movement,
      mitre_tecnique = mitre.tecnique.remote_services,
      mitre_sub_tecnique = mitre.sub_tecnique.ssh,
      mitre_id = "T1021.004"
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_ssh_obsolete_client:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_ndpi_ssh_obsolete_client.format(ifid, alert, alert_type_params)
   if alert_type_params and alert_type_params.proto and alert_type_params.proto.ssh then   
      local client_signature = alert_type_params.proto.ssh.client_signature
      return i18n("flow_risk.ndpi_ssh_obsolete_client_version_or_cipher_signature", { signature = client_signature }) 
   end
   return i18n("flow_risk.ndpi_ssh_obsolete_client_version_or_cipher")
end

-- #######################################################

return alert_ndpi_ssh_obsolete_client
