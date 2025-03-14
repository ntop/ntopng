--
-- (C) 2019-25 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
-- Import Mitre Att&ck utils
local mitre = require "mitre_utils"

local format_utils = require "format_utils"

-- ##############################################

local alert_qoe_degraded = classes.class(alert)

-- ##############################################

alert_qoe_degraded.meta = {
   alert_key = flow_alert_keys.flow_alert_qoe_degraded,
   i18n_title = "flow_checks_config.qoe_degraded_title",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_values = {
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_flow_param The first alert param
-- @param another_flow_param The second alert param
-- @return A table with the alert built
function alert_qoe_degraded:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_qoe_degraded.format(ifid, alert, alert_type_params)
   local qoe = "Degraded"
   if alert_type_params["qoe_score"] <= 30 then
      qoe = "Poor"
   end
   
   return i18n("alert_messages.qoe_degraded", {
      qoe = qoe,
      qoe_score = alert_type_params["qoe_score"]
   })

end

-- #######################################################

return alert_qoe_degraded
