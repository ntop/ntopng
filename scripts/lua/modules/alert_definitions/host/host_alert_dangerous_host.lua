--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local host_alert_keys = require "host_alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

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

return host_alert_dangerous_host
