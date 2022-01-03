--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local host_alert_keys = require "host_alert_keys"

local alert_creators = require "alert_creators"
local json = require("dkjson")
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local host_alert_score_threshold = classes.class(alert)

-- ##############################################

host_alert_score_threshold.meta = {
  alert_key = host_alert_keys.host_alert_score_threshold,
  i18n_title = "alerts_thresholds_config.score_threshold_title",
  icon = "fas fa-fw fa-life-ring",
  has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function host_alert_score_threshold:init(threshold)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      threshold = threshold,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_score_threshold.format(ifid, alert, alert_type_params)
   local alert_consts = require("alert_consts")
   local host = alert_consts.formatHostAlert(ifid, alert["ip"], alert["vlan_id"])
   local threshold = alert_type_params["threshold"] or 0

   if (tonumber(alert_type_params["value"]) > tonumber(threshold)) and (threshold > 0) then
      -- threshold due to threshold crossed
      return i18n("alert_messages.score_threshold", {
         entity = host,
         value = alert_type_params["value"],
         threshold = threshold,
      })
   end
end

-- #######################################################

return host_alert_score_threshold
