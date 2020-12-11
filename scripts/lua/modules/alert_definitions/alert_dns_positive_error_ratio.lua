--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"
local format_utils = require "format_utils"
local json = require("dkjson")

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param alert_granularity A granularity as defined in `alert_consts.alerts_granularities`
-- @param alert_subtype A string with the subtype of the alert
-- @param requests The number of requests
-- @param replies The number of replies
-- @return A table with the alert built
local function createDnsPositiveErrorRatio(alert_severity, alert_granularity, type, positives, errors)
   local built = {
      alert_granularity = alert_granularity,
      alert_severity = alert_severity,
      alert_type_params = {
   type = type,
	 positives = positives,
	 errors= errors,
      }
   }

   return built
end

-- #######################################################

function dnsPositiveErrorRatioFormatter(ifid, alert, info)
  local type = ""

  if info.type == "dns_rcvd" then
    type = "Received"
  else
    type = "Sent"
  end
  return(i18n("dns_positive_error_ratio.positive_error_ratio_descr", {
    type = type,
    positives = info.positives,
    errors = info.errors,
  }))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_dns_positive_error_ratio,
  i18n_title = "dns_positive_error_ratio.title",
  i18n_description = dnsPositiveErrorRatioFormatter,
  icon = "fas fa-exclamation",
  creator = createDnsPositiveErrorRatio,
}
