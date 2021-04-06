--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local host_alert_keys = require "host_alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local format_utils = require "format_utils"
local json = require("dkjson")
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local host_alert_replies_requests_ratio = classes.class(alert)

-- ##############################################

host_alert_replies_requests_ratio.meta = {
  alert_key = host_alert_keys.host_alert_replies_requests_ratio,
  i18n_title = "entity_thresholds.request_reply_ratio_title",
  icon = "fas fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param requests The number of requests
-- @param replies The number of replies
-- @return A table with the alert built
function host_alert_replies_requests_ratio:init(requests, replies)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      requests = requests, 
      replies = replies,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_replies_requests_ratio.format(ifid, alert, alert_type_params)
  local alert_consts = require("alert_consts")

  local entity = firstToUpper(alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"]))
  local ratio

  if((alert_type_params.replies ~= nil) and (alert_type_params.requests ~= nil)) then
    ratio = round(math.min((alert_type_params.replies * 100) / (alert_type_params.requests + 1), 100), 1)
  else
    ratio = 1
  end

  local labels = {i18n("alerts_dashboard.reqs_repls_ratio_for", {
			  entity = entity,
			  host_category = format_utils.formatAddressCategory((json.decode(alert.alert_json)).alert_generation.host_info)})}
  
  if alert_type_params.dns_sent_rcvd_ratio < alert_type_params.ratio then
     labels[#labels + 1] = i18n("alerts_dashboard.dns_sent_rcvd_ratio", { ratio = alert_type_params.dns_sent_rcvd_ratio, threshold = alert_type_params.ratio})
  end
  if alert_type_params.dns_rcvd_sent_ratio < alert_type_params.ratio then
     labels[#labels + 1] = i18n("alerts_dashboard.dns_rcvd_sent_ratio", { ratio = alert_type_params.dns_rcvd_sent_ratio, threshold = alert_type_params.ratio})
  end
  if alert_type_params.http_sent_rcvd_ratio < alert_type_params.ratio then
     labels[#labels + 1] = i18n("alerts_dashboard.http_sent_rcvd_ratio", { ratio = alert_type_params.http_sent_rcvd_ratio, threshold = alert_type_params.ratio})
  end
  if alert_type_params.http_rcvd_sent_ratio < alert_type_params.ratio then
     labels[#labels + 1] = i18n("alerts_dashboard.http_rcvd_sent_ratio", { ratio = alert_type_params.http_rcvd_sent_ratio, threshold = alert_type_params.ratio})
  end

  return table.concat(labels, " ")
end

-- #######################################################

return host_alert_replies_requests_ratio
