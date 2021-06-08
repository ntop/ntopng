--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local format_utils = require("format_utils")
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_flow_low_goodput = classes.class(alert)

-- ##############################################

alert_flow_low_goodput.meta = {
   alert_key = flow_alert_keys.flow_alert_low_goodput,
   i18n_title = "alerts_dashboard.flow_low_goodput",
   icon = "fas fa-fw fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_flow_low_goodput:init(goodput_ratio)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      goodput_ratio = goodput_ratio
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_flow_low_goodput.format(ifid, alert, alert_type_params)
   if alert_type_params and alert_type_params.goodput_ratio then
      return i18n("flow_details.flow_low_goodput", { ratio = format_utils.round(alert_type_params.goodput_ratio, 2) })
   end
end

-- #######################################################

return alert_flow_low_goodput
