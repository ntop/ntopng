--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_ndpi_tls_old_protocol_version = classes.class(alert)

-- ##############################################

alert_ndpi_tls_old_protocol_version.meta = {
   alert_key = flow_alert_keys.flow_alert_ndpi_tls_old_protocol_version,
   i18n_title = "flow_details.tls_old_protocol_version",
   icon = "fas fa-fw fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param tls_version A number indicating the TLS version detected, or nil when version is not available
-- @return A table with the alert built
function alert_ndpi_tls_old_protocol_version:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_ndpi_tls_old_protocol_version.format(ifid, alert, alert_type_params)
   local msg = ""

   if(alert_type_params and alert_type_params.tls_version) then
      local tls_version = alert_type_params.tls_version
      local ver_str

      if tls_version and tls_version > 0 then
	 ver_str = ntop.getTLSVersionName(tls_version)
      else
	 ver_str = string.format("< TLSv1.1")
      end

      msg = i18n("alerts_dashboard.tls_old_protocol_version", {version = ver_str})
   end

   return(msg)
end

function alert_ndpi_tls_old_protocol_version.alert_retention_policy_key(alert_info)
   return {"srv_ip","srv_port"}
end

-- #######################################################

return alert_ndpi_tls_old_protocol_version
