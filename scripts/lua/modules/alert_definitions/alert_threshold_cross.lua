--
-- (C) 2019-20 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local json = require("dkjson")
local alert_creators = require "alert_creators"
local format_utils = require "format_utils"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_threshold_cross = classes.class(alert)

-- ##############################################

alert_threshold_cross.meta = {
  alert_key = alert_keys.ntopng.alert_threshold_cross,
  i18n_title = "alerts_dashboard.threashold_cross",
  icon = "fas fa-arrow-circle-up",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param metric Same as `alert_subtype`
-- @param value A number indicating the measure which crossed the threshold
-- @param operator A string indicating the operator used when evaluating the threshold, one of "gt", ">", "<"
-- @param threshold A number indicating the threshold compared with `value`  using operator
-- @return A table with the alert built
function alert_threshold_cross:init(metric, value, operator, threshold)
   -- Call the paren constructor
   self.super:init()

   self.alert_type_params = alert_creators.createThresholdCross(metric, value, operator, threshold)
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_threshold_cross.format(ifid, alert, alert_type_params)
  local alert_consts = require("alert_consts")
  local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])
  local engine_label = alert_consts.alertEngineLabel(alert_consts.alertEngine(alert_consts.sec2granularity(alert["alert_granularity"])))

  return i18n("alert_messages.threshold_crossed", {
    granularity = engine_label,
    metric = alert_type_params.metric,
    entity = entity,
    host_category = format_utils.formatAddressCategory((json.decode(alert.alert_json)).alert_generation.host_info),
    value = string.format("%u", math.ceil(alert_type_params.value)),
    op = "&".. (alert_type_params.operator or "gt") ..";",
    threshold = alert_type_params.threshold,
  })
end

-- #######################################################

return alert_threshold_cross
