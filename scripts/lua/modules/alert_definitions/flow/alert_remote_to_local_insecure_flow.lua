--
-- (C) 2019-26 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"

local format_utils = require "format_utils"
local json = require("dkjson")
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
-- Import Mitre Att&ck utils
local mitre = require "mitre_utils"

-- ##############################################

local alert_remote_to_local_insecure_flow = classes.class(alert)

-- ##############################################

alert_remote_to_local_insecure_flow.meta = {
   alert_key = flow_alert_keys.flow_alert_remote_to_local_insecure_proto,
   i18n_title = "flow_checks_config.remote_to_local_insecure_flow_title",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.lateral_movement,
      mitre_technique = mitre.technique.remote_services,
      mitre_sub_technique = mitre.sub_technique.remote_desktop_proto,
      mitre_id = "T1021.001"
   },

   has_victim = true,
   has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_flow_param The first alert param
-- @param another_flow_param The second alert param
-- @return A table with the alert built
function alert_remote_to_local_insecure_flow:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_remote_to_local_insecure_flow.format(ifid, alert, alert_type_params)
   local breeds = {
      [3] = "alerts_dashboard.ndpi_unsafe_protocol_title",
      [4] = "alerts_dashboard.ndpi_potentially_dangerous_protocol_title",
      [5] = "alerts_dashboard.ndpi_dangerous_protocol_title",
   }
   local categories = {
      [100] = "ndpi_categories.Malware",
      [102] = "ndpi_categories.Banned_Site",
   }

   local l7_proto = tonumber(alert.l7_proto) or 0
   if l7_proto == 0 then
      l7_proto = tonumber(alert.l7_master_proto) or 0
   end
   local proto = interface.getnDPIProtoName(l7_proto)
   local breed = breeds[alert_type_params.ndpi_breed]
   local category = categories[alert_type_params.ndpi_category]

   local alert_message
   if breed then
      alert_message = i18n("alert_messages.remote_to_local_insecure_flow_breed", { proto = proto, breed = i18n(breed) })
      if category then
         alert_message = alert_message .. i18n("alert_messages.remote_to_local_insecure_proto_category_info", { ndpi_category = i18n(category) })
      end
   else
      alert_message = i18n("alert_messages.remote_to_local_insecure_flow_category", { proto = proto, category = i18n(category or "ndpi_categories.Unspecified") })
   end

   return alert_message
end

-- #######################################################

return alert_remote_to_local_insecure_flow
