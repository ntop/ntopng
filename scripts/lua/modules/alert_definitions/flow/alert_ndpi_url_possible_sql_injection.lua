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

local alert_ndpi_url_possible_sql_injection = classes.class(alert)

-- ##############################################

alert_ndpi_url_possible_sql_injection.meta = {
   alert_key  = flow_alert_keys.flow_alert_ndpi_url_possible_sql_injection,
   i18n_title = "alerts_dashboard.ndpi_url_possible_sql_injection_title",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.initial_access,
      mitre_tecnique = mitre.tecnique.exploit_pub_facing_app,
      mitre_id = "T1190"
   },

   has_victim = true,
   has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_url_possible_sql_injection:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_ndpi_url_possible_sql_injection.format(ifid, alert, alert_type_params)
   if alert_type_params and alert_type_params.proto and alert_type_params.proto.http then
      return i18n('alerts_dashboard.ndpi_url_possible_sql_injection_descr', { url =  alert_type_params.proto.http.last_url})
   else
      return i18n('alerts_dashboard.ndpi_url_possible_sql_injection_descr_generic')
   end
end

-- #######################################################

return alert_ndpi_url_possible_sql_injection
