--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local host_alert_keys = require "host_alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local alert_creators = require "alert_creators"
local format_utils = require "format_utils"
local json = require("dkjson")
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local host_alert_flow_anomaly = classes.class(alert)

-- ##############################################

host_alert_flow_anomaly.meta = {
  alert_key = host_alert_keys.host_alert_flows_anomaly,
  i18n_title = "alerts_dashboard.flow_anomaly",
  icon = "fas fa-life-ring",
  has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function host_alert_flow_anomaly:init()
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {}
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_flow_anomaly.format(ifid, alert, alert_type_params)
  local alert_consts = require("alert_consts")
  local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])
  local value = alert_type_params.value
  local alert_json = json.decode(alert.alert_json)
  local is_client_alert = alert_json.is_client_alert
  local role
  local host = alert.alert_entity_val
  
  if(is_client_alert) then
     role = "client"
  else
     role = "server"
  end

  return i18n("alert_messages.flow_number_anomaly", {
		 role = role,
		 host = host,
		 value = alert_type_params["value"],
		 lower_bound = alert_type_params["lower_bound"],
		 upper_bound = alert_type_params["upper_bound"],
  })
end

-- #######################################################

return host_alert_flow_anomaly
