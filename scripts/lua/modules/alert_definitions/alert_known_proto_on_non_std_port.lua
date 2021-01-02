--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local status_keys = require "status_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_known_proto_on_non_std_port = classes.class(alert)

-- ##############################################

alert_known_proto_on_non_std_port.meta = {   
   status_key = status_keys.ntopng.status_known_proto_on_non_std_port,
   alert_key = alert_keys.ntopng.alert_known_proto_on_non_std_port,
   i18n_title = "alerts_dashboard.known_proto_on_non_std_port",
   icon = "fas fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param info A lua table containing flow information obtained with `flow.getInfo()`
-- @return A table with the alert built
function alert_known_proto_on_non_std_port:init(info)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = info
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_known_proto_on_non_std_port.format(ifid, alert, alert_type_params)
   local res = i18n("alerts_dashboard.known_proto_on_non_std_port")

   if info then
      local app = alert_type_params["proto.ndpi_app"] or alert_type_params["proto.ndpi"]

      if app then
	 res = i18n("alerts_dashboard.known_proto_on_non_std_port_full", {app = app, port = alert_type_params["srv.port"]})
      end
   end

   return res
end

-- #######################################################

return alert_known_proto_on_non_std_port
