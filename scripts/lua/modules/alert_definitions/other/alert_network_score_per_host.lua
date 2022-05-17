--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
local format_utils = require "format_utils"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_network_score_per_host = classes.class(alert)

-- ##############################################

alert_network_score_per_host.meta = {
  alert_key = other_alert_keys.alert_network_score_per_host,
  i18n_title = "checks.network_score_per_host_title",
  icon = "fas fa-fw fa-arrow-circle-up",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param metric Same as `alert_subtype`
-- @param value A number indicating the measure which crossed the threshold
-- @param operator A string indicating the operator used when evaluating the threshold, one of "gt", ">", "<"
-- @param threshold A number indicating the threshold compared with `value`  using operator
-- @return A table with the alert built
function alert_network_score_per_host:init(score, threshold, num_hosts, threshold_per_host)
  -- Call the parent constructor
  self.super:init()

  self.alert_type_params = {
    score = score,
    threshold = threshold,
    num_hosts = num_hosts,
    threshold_per_host = threshold_per_host,
  }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_network_score_per_host.format(ifid, alert, alert_type_params)
  return i18n("alert_messages.network_score_per_host", {
    score = format_utils.formatValue(alert_type_params.score),
    threshold = format_utils.formatValue(alert_type_params.threshold),
    num_hosts = format_utils.formatValue(alert_type_params.num_hosts or 1),
    threshold_per_host = format_utils.formatValue(alert_type_params.threshold_per_host or 100),
  })
end

-- #######################################################

return alert_network_score_per_host
