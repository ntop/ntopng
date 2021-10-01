--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local host_alert_keys = require "host_alert_keys"

local alert_creators = require "alert_creators"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local host_alert_remote_connection = classes.class(alert)

-- ##############################################

host_alert_remote_connection.meta = {
  alert_key = host_alert_keys.host_alert_remote_connection,
  i18n_title = "alerts_dashboard.remote_connection_title",
  icon = "fas fa-fw fa-info",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function host_alert_remote_connection:init()
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
function host_alert_remote_connection.format(ifid, alert, alert_type_params)
   local alert_consts = require "alert_consts"
   local host = alert_consts.formatHostAlert(ifid, alert["ip"], alert["vlan_id"])

   return i18n("alerts_dashboard.remote_connection_alert_descr", {
		  host = host,
		  connections = alert_type_params["num_flows"],
   })
end

-- #######################################################

-- @brief Prepare a table containing a set of filters useful to query historical flows that contributed to the generation of this alert
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_remote_connection.filter_to_past_flows(ifid, alert, alert_type_params)
   local res = {}
   local host_key = hostinfo2hostkey({ip = alert["ip"], vlan = alert["vlan_id"]})

   -- Look for the IP both as client and as server as the alert does not differentiate
   res["ip"] = host_key
   -- Category FileSharing, not just a single protocol
   res["l7cat"] = "RemoteAccess"

   return res
end

-- #######################################################

return host_alert_remote_connection
