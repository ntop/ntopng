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

local alert_rare_destination = classes.class(alert)

-- ##############################################

alert_rare_destination.meta = {
   alert_key  = flow_alert_keys.flow_alert_rare_destination,
   i18n_title = "flow_checks_config.rare_destination",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_tactic = "mitre.tactic.c_and_c",
   mitre_tecnique = "mitre.tecnique.dynamic_resolution",
   mitre_ID = "T1568",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_rare_destination:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_rare_destination.format(ifid, alert, alert_type_params)
   if not alert_type_params then
      tprint("-1-")
      return i18n("alerts_dashboard.rare_destination_description", {destination = ""})
   else
      local ret = i18n("alerts_dashboard.rare_destination_description", {destination = alert_type_params["destination"]})
      tprint("-2->"..ret)
      return(ret)
   end
end

-- #######################################################

return alert_rare_destination
