--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_tls_certificate_expired = classes.class(alert)

-- ##############################################

alert_tls_certificate_expired.meta = {
   alert_key = flow_alert_keys.flow_alert_tls_certificate_expired,
   i18n_title = "flow_details.tls_certificate_expired",
   icon = "fas fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param tls_info A lua table with TLS info gererated calling `flow.getTLSInfo()`
-- @return A table with the alert built
function alert_tls_certificate_expired:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_tls_certificate_expired.format(ifid, alert, alert_type_params)
   if not alert_type_params then
      return
   end

   local crts = {}
   if alert_type_params["protos.tls.notBefore"] and alert_type_params["protos.tls.notAfter"] then
      crts[#crts + 1] = formatEpoch(alert_type_params["protos.tls.notBefore"])
      crts[#crts + 1] = formatEpoch(alert_type_params["protos.tls.notAfter"])
      return string.format("[%s]",  table.concat(crts, " - "))
   else
      return ""
   end
end

-- #######################################################

return alert_tls_certificate_expired
