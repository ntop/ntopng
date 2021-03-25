--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local flow_risk_utils = require "flow_risk_utils"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_flow_risk = classes.class(alert)

-- ##############################################

alert_flow_risk.meta = {
   alert_key = flow_alert_keys.flow_alert_flow_risk,
   i18n_title = "alerts_dashboard.flow_risk",
   icon = "fas fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param risk_id Integer nDPI flow risk identifier
-- @return A table with the alert built
function alert_flow_risk:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_flow_risk.format(ifid, alert, alert_type_params)
   -- No need to do special formatting of flow risk here, risks are already formatted
   -- inside the flow details page
   local res = i18n("alerts_dashboard.flow_risk")

   if((alert_type_params ~= nil) and alert_type_params.risk_id) then
      res = flow_risk_utils.risk_id_2_i18n(alert_type_params.risk_id)
   end

   return res
end

-- #######################################################

return alert_flow_risk
