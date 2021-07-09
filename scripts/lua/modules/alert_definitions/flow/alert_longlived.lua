--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local json = require "dkjson"

-- ##############################################

local alert_longlived = classes.class(alert)

-- ##############################################

alert_longlived.meta = {
   alert_key = flow_alert_keys.flow_alert_longlived,
   i18n_title = "flow_details.longlived_flow",
   icon = "fas fa-fw fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param longlived_threshold Threshold, in seconds, for a flow to be considered longlived
-- @return A table with the alert built
function alert_longlived:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_longlived.format(ifid, alert, alert_type_params)
   local threshold = ""
   local res = i18n("flow_details.longlived_flow")

   if alert_type_params then
      if alert_type_params["longlived.threshold"] then
	 threshold = alert_type_params["longlived.threshold"]
      end

      res = string.format("%s<sup><i class='fas fa-fw fa-info-circle' aria-hidden='true' title='"..i18n("flow_details.longlived_flow_descr").."'></i></sup>", res)

      if threshold ~= "" then
	 res = string.format("%s [%s]", res, i18n("flow_details.longlived_exceeded", {amount = secondsToTime(threshold)}))
      end
   end

   local alert_json = json.decode(alert["json"])
   if alert_json and not isEmptyString(alert_json["info"]) then
      res = string.format("%s [%s]", res, alert_json["info"])
   end

   return res
end

-- #######################################################

return alert_longlived
