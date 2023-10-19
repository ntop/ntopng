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

local host_alert_flow_anomaly = classes.class(alert)

-- ##############################################

host_alert_flow_anomaly.meta = {
  alert_key = host_alert_keys.host_alert_flows_anomaly,
  i18n_title = "alerts_dashboard.flow_anomaly",
  icon = "fas fa-fw fa-life-ring",
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
   local is_both = alert_type_params["is_both"]
   local is_client_alert = alert_type_params["is_client_alert"]
   local role

   if(is_both) then
      role = i18n("client_and_server")
   elseif(is_client_alert) then
      role = i18n("client")
   else
      role = i18n("server")
   end

   return i18n("alert_messages.flow_number_anomaly", {
      role = role,
      value = alert_type_params["value"],
      lower_bound = alert_type_params["lower_bound"],
      upper_bound = alert_type_params["upper_bound"],
   })
end

-- #######################################################

-- @brief Prepare a table containing a set of filters useful to query historical flows that contributed to the generation of this alert
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_flow_anomaly.filter_to_past_flows(ifid, alert, alert_type_params)
   local res = {}
   local host_key = hostinfo2hostkey({ip = alert["ip"], vlan = alert["vlan_id"]})

   -- Filter by client or server, depending on whether this alert is as-client or as-server
   if alert["is_client"] == true or alert["is_client"] == "1" then
      res["cli_ip"] = host_key
   elseif alert["is_server"] == true or alert["is_server"] == "1" then
      res["srv_ip"] = host_key
   end

   -- No other filter can be set
   
   return res
end

-- #######################################################

return host_alert_flow_anomaly
