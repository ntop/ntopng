--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local host_alert_keys = require "host_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local host_alert_dns_requests_errors_ratio = classes.class(alert)

-- ##############################################

host_alert_dns_requests_errors_ratio.meta = {
   alert_key = host_alert_keys.host_alert_dns_requests_errors_ratio,
   i18n_title = "dns_positive_error_ratio.title",
   icon = "fas fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param requests The number of requests
-- @param replies The number of replies
-- @return A table with the alert built
function host_alert_dns_requests_errors_ratio:init(type, positives, errors)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      type = type,
      positives = positives,
      errors = errors,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_dns_requests_errors_ratio.format(ifid, alert, alert_type_params)
   local type = ""

   if alert_type_params.type == "dns_rcvd" then
      type = "Received"
   else
      type = "Sent"
   end

   return(i18n("dns_positive_error_ratio.positive_error_ratio_descr", {
		  type = type,
		  positives = alert_type_params.positives,
		  errors = alert_type_params.errors,
   }))
end

-- #######################################################

return host_alert_dns_requests_errors_ratio
