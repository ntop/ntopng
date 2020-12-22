--
-- (C) 2019-20 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
local status_keys = require "status_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_tls_old_version = classes.class(alert)

-- ##############################################

alert_tls_old_version.meta = {
   status_key = status_keys.ntopng.status_tls_old_protocol_version,
   alert_key = alert_keys.ntopng.alert_tls_old_protocol_version,
   i18n_title = "flow_details.tls_old_protocol_version",
   icon = "fas fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param tls_version A number indicating the TLS version detected, or nil when version is not available
-- @return A table with the alert built
function alert_tls_old_version:init(tls_version)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      tls_version = tls_version,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_tls_old_version.format(ifid, alert, alert_type_params)
   local msg = i18n("flow_details.tls_old_protocol_version")

   if(alert_type_params and alert_type_params.tls_version) then
      local ver_str = ntop.getTLSVersionName(alert_type_params.tls_version)

      if(ver_str == nil) then
	 ver_str = string.format("%u", alert_type_params.tls_version)
      end

      msg = msg .. " (" .. ver_str .. ")"
   end

   return(msg)
end

-- #######################################################

return alert_tls_old_version
