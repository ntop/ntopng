--
-- (C) 2019-20 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
local status_keys = require "flow_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_tls_certificate_mismatch = classes.class(alert)

-- ##############################################

alert_tls_certificate_mismatch.meta = {
   status_key = status_keys.ntopng.status_tls_certificate_mismatch,
   alert_key = alert_keys.ntopng.alert_tls_certificate_mismatch,
   i18n_title = "flow_details.tls_certificate_mismatch",
   icon = "fas fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param tls_info A lua table with TLS info gererated calling `flow.getTLSInfo()`
-- @return A table with the alert built
function alert_tls_certificate_mismatch:init(tls_info)
   -- Call the parent constructor
   self.super:init()

   tls_info = tls_info or {}
   local server_cn = tls_info["protos.tls.server_names"] or ""
   local client_cn = tls_info["protos.tls.client_requested_server_name"] or ""

   self.alert_type_params = {
      ["tls_crt.cli"] = client_cn,
      ["tls_crt.srv"] = server_cn,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_tls_certificate_mismatch.format(ifid, alert, alert_type_params)
   if not alert_type_params then
      return i18n("flow_details.tls_certificate_mismatch")
   end

   local crts = {}
   if not isEmptyString(alert_type_params["tls_crt.cli"]) then
      crts[#crts + 1] = string.format("[%s: %s]", i18n("flow_details.client_requested"), alert_type_params["tls_crt.cli"]:gsub(",", ", "))
   end

   if not isEmptyString(alert_type_params["tls_crt.srv"]) then
      crts[#crts + 1] = string.format("[%s: %s]", i18n("flow_details.tls_server_names"), alert_type_params["tls_crt.srv"]:gsub(",", ", "))
   end

   return string.format("%s %s", i18n("flow_details.tls_certificate_mismatch"), table.concat(crts, " "))
end

-- #######################################################

return alert_tls_certificate_mismatch
