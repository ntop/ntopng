--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_ndpi_suspicious_dga_domain = classes.class(alert)

-- ##############################################

alert_ndpi_suspicious_dga_domain.meta = {
   alert_key  = flow_alert_keys.flow_alert_ndpi_suspicious_dga_domain,
   i18n_title = "alerts_dashboard.ndpi_suspicious_dga_domain_title",
   icon = "fas fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_suspicious_dga_domain:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_ndpi_suspicious_dga_domain.format(ifid, alert, alert_type_params)
   if alert_type_params.dga_domain then
      return i18n("alert_messages.suspicious_dga_domain", {
		     domain = alert_type_params["dga_domain"],
      })
   else
      return
   end
end

-- #######################################################

return alert_ndpi_suspicious_dga_domain
