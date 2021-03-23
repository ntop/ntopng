--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local format_utils = require "format_utils"
local json = require("dkjson")
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_request_reply_ratio = classes.class(alert)

-- ##############################################

alert_request_reply_ratio.meta = {
  alert_key = alert_keys.ntopng.alert_request_reply_ratio,
  i18n_title = "entity_thresholds.request_reply_ratio_title",
  icon = "fas fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param requests The number of requests
-- @param replies The number of replies
-- @return A table with the alert built
function alert_request_reply_ratio:init(requests, replies)
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
function alert_request_reply_ratio.format(ifid, alert, alert_type_params)
  local alert_consts = require("alert_consts")

  local entity = firstToUpper(alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"]))
  local engine_label = alert_consts.alertEngineLabel(alert_consts.alertEngine(alert_consts.sec2granularity(alert["alert_granularity"])))
  local ratio

  if((alert_type_params.replies ~= nil) and (alert_type_params.requests ~= nil)) then
    ratio = round(math.min((alert_type_params.replies * 100) / (alert_type_params.requests + 1), 100), 1)
  else
    ratio = 1
  end
		
  -- {i18_string, what}
  local subtype_to_info = {
    dns_sent = {"alerts_dashboard.too_low_replies_received", "DNS"},
    dns_rcvd = {"alerts_dashboard.too_low_replies_sent", "DNS"},
    http_sent = {"alerts_dashboard.too_low_replies_received", "HTTP"},
    http_rcvd = {"alerts_dashboard.too_low_replies_sent", "HTTP"},
    icmp_echo_sent = {"alerts_dashboard.too_low_replies_received", "ICMP ECHO"},
    icmp_echo_rcvd = {"alerts_dashboard.too_low_replies_received", "ICMP ECHO"},
  }

  local subtype_info = subtype_to_info[alert.alert_subtype]

  return(i18n(subtype_info[1], {
    entity = entity,
    host_category = format_utils.formatAddressCategory((json.decode(alert.alert_json)).alert_generation.host_info),
    granularity = engine_label,
    ratio = ratio,
    requests = i18n(
      ternary(alert_type_params.requests == 1, "alerts_dashboard.one_request", "alerts_dashboard.many_requests"),
      {count = formatValue(alert_type_params.requests), what = subtype_info[2]}),
    replies =  i18n(
      ternary(alert_type_params.replies == 1, "alerts_dashboard.one_reply", "alerts_dashboard.many_replies"),
      {count = formatValue(alert_type_params.replies), what = subtype_info[2]}),
  }))
end

-- #######################################################

return alert_request_reply_ratio
