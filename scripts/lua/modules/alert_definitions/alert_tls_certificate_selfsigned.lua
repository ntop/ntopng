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

local alert_tls_certificate_selfsigned = classes.class(alert)

-- ##############################################

alert_tls_certificate_selfsigned.meta = {
   status_key = status_keys.ntopng.status_tls_certificate_selfsigned,
   alert_key = alert_keys.ntopng.alert_tls_certificate_selfsigned,
   i18n_title = "flow_details.tls_certificate_selfsigned",
   icon = "fas fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param tls_info A lua table with TLS info gererated calling `flow.getTLSInfo()`
-- @return A table with the alert built
function alert_tls_certificate_selfsigned:init(tls_info)
   -- Call the parent constructor
   self.super:init()

   tls_info = tls_info or {}

   self.alert_type_params = {
      ["tls_crt.issuerDN"]  = tls_info["protos.tls.issuerDN"] or "",
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_tls_certificate_selfsigned.format(ifid, alert, alert_type_params)
   if not alert_type_params then
      return i18n("flow_details.tls_certificate_selfsigned")
   end

   local crts = {}
   crts[#crts + 1] = alert_type_params["tls_crt.issuerDN"]

   return string.format("%s [Issuer/Subject: %s]", i18n("flow_details.tls_certificate_selfsigned"), table.concat(crts, " - "))
end

-- #######################################################

return alert_tls_certificate_selfsigned
