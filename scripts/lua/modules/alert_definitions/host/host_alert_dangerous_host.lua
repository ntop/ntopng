--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local host_alert_keys = require "host_alert_keys"

local json = require("dkjson")
local alert_creators = require "alert_creators"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local host_alert_dangerous_host = classes.class(alert)

-- ##############################################

host_alert_dangerous_host.meta = {
  alert_key = host_alert_keys.host_alert_dangerous_host,
  i18n_title = "alerts_dashboard.dangerous_host_title",
  icon = "fas fa-exclamation-triangle",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function host_alert_dangerous_host:init(metric, value, operator, threshold)
   -- Call the parent constructor
   self.super:init()
   
   self.alert_type_params = {}
   self.alert_type_params = alert_creators.createThresholdCross(metric, value, operator, threshold)
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_dangerous_host.format(ifid, alert, alert_type_params)
  local alert_consts = require("alert_consts")
  local entity = alert_consts.formatHostAlert(ifid, alert["ip"], alert["vlan_id"])
  
  return i18n("alert_messages.host_alert_dangerous_host", {
    entity = entity,
    score = alert_type_params["score"],
    duration = alert_type_params["consecutive_high_score"],
  })
end

-- #######################################################

-- @brief Prepare a table containing a set of filters useful to query historical flows that contributed to the generation of this alert
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_dangerous_host.filter_to_past_flows(ifid, alert, alert_type_params)
   local res = {}
   local host_key = hostinfo2hostkey({ip = alert["ip"], vlan = alert["vlan_id"]})

   -- Look for the IP as client as currently the alert is for dangerous clients
   res["cli_ip"] = host_key
   -- A non-normal flow status
   res["score"] = true 

   return res
end

-- #######################################################

return host_alert_dangerous_host
