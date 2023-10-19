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

local alert_tls_certificate_mismatch = classes.class(alert)

-- ##############################################

alert_tls_certificate_mismatch.meta = {
   alert_key = flow_alert_keys.flow_alert_tls_certificate_mismatch,
   i18n_title = "flow_details.tls_certificate_mismatch",
   icon = "fas fa-fw fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param tls_info A lua table with TLS info gererated calling `flow.getTLSInfo()`
-- @return A table with the alert built
function alert_tls_certificate_mismatch:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_tls_certificate_mismatch.format(ifid, alert, alert_type_params)
   if not alert_type_params then
      return
   end

   local crts = {}
   if not isEmptyString(alert_type_params["protos.tls.client_requested_server_name"]) then
      crts[#crts + 1] = string.format("[%s: %s]", i18n("flow_details.client_requested"), alert_type_params["protos.tls.client_requested_server_name"]:gsub(",", ", "))
   end

   if not isEmptyString(alert_type_params["protos.tls.server_names"]) then
      crts[#crts + 1] = string.format("[%s: %s]", i18n("flow_details.tls_server_names"), alert_type_params["protos.tls.server_names"]:gsub(",", ", "))
   end

   return string.format("%s %s", i18n("flow_risk.ndpi_tls_certificate_mismatch"), table.concat(crts, ""))
end

-- #######################################################

return alert_tls_certificate_mismatch
