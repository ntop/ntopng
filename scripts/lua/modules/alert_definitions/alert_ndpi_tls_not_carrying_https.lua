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

local alert_ndpi_tls_not_carrying_https = classes.class(alert)

-- ##############################################

alert_ndpi_tls_not_carrying_https.meta = {
   status_key = status_keys.ntopng.status_ndpi_tls_not_carrying_https,
   alert_key  = alert_keys.ntopng.alert_ndpi_tls_not_carrying_https,
   i18n_title = "alerts_dashboard.ndpi_tls_not_carrying_https_title",
   icon = "fas fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_tls_not_carrying_https:init()
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {}
end

-- #######################################################

function alert_ndpi_tls_not_carrying_https.format(ifid, alert, alert_type_params)
   return i18n("flow_risk.ndpi_tls_not_carrying_https")
end

-- #######################################################

return alert_ndpi_tls_not_carrying_https
