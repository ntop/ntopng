--
-- (C) 2019-21 - ntop.org
--
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

local alert_elephant_flow = classes.class(alert)

-- ##############################################

alert_elephant_flow.meta = {
   alert_key = flow_alert_keys.flow_alert_elephant_flow,
   i18n_title = "flow_details.elephant_flow",
   icon = "fas fa-fw fa-exclamation",
}

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param l2r_threshold Local-to-Remote threshold, in bytes, for a flow to be considered an elephant
-- @param r2l_threshold Remote-to-Local threshold, in bytes, for a flow to be considered an elephant
-- @return A table with the alert built
function alert_elephant_flow:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_elephant_flow.format(ifid, alert, alert_type_params)
   local threshold = ""
   local res = i18n("flow_details.elephant_flow")

   if alert_type_params then
      local l2r_bytes = bytesToSize(alert_type_params["l2r_bytes"])

      if alert_type_params["l2r_bytes"] > alert_type_params["l2r_threshold"] and alert_type_params["l2r_threshold"] > 0 then
	 l2r_bytes = l2r_bytes .." > "..bytesToSize(alert_type_params["l2r_threshold"])
      end

      local r2l_bytes = bytesToSize(alert_type_params["r2l_bytes"])
      if alert_type_params["r2l_bytes"] > alert_type_params["r2l_threshold"] and alert_type_params["l2r_threshold"] > 0 then
	 r2l_bytes = r2l_bytes .. " > "..bytesToSize(alert_type_params["r2l_threshold"])
      end

      res = string.format("%s<sup><i class='fas fa-info-circle' aria-hidden='true' title='"..i18n("flow_details.elephant_flow_descr").."'></i></sup>", res)
      res = string.format("%s %s", res, i18n("flow_details.elephant_exceeded", {l2r = l2r_bytes, r2l = r2l_bytes}))
   end

   local alert_json = json.decode(alert["json"])
   if alert_json and not isEmptyString(alert_json["info"]) then
      res = string.format("%s [%s]", res, alert_json["info"])
   end

   return res
end

-- #######################################################

return alert_elephant_flow

-- #######################################################
