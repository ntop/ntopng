--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"

local json = require("dkjson")
local alert_creators = require "alert_creators"
local format_utils = require "format_utils"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_port_too_many_macs = classes.class(alert)

-- ##############################################

alert_port_too_many_macs.meta = {
  alert_key = other_alert_keys.alert_port_too_many_macs,
  i18n_title = "alerts_dashboard.alert_port_too_many_macs_title",
  icon = "fas fa-fw fa-arrow-circle-up",
  entities = {
     alert_entities.snmp_device,
  }
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param metric Same as `alert_subtype`
-- @param value A number indicating the measure which crossed the threshold
-- @param operator A string indicating the operator used when evaluating the threshold, one of "gt", ">", "<"
-- @param threshold A number indicating the threshold compared with `value`  using operator
-- @return A table with the alert built
function alert_port_too_many_macs:init(metric, value, operator, threshold)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = alert_creators.createThresholdCross(metric, value, operator, threshold)
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_port_too_many_macs.format(ifid, alert, alert_type_params)
  return i18n("alert_messages.alert_port_too_many_macs", {
    value = format_utils.formatValue(format_utils.round(alert_type_params.value, 2)),
    op = "&".. (alert_type_params.operator or "gt") ..";",
    threshold = format_utils.formatValue(alert_type_params.threshold),
    ip = alert.ip,
    port = alert.port,
    url = snmpDeviceUrl(alert.ip),
    port_url = snmpIfaceUrl(alert.ip, alert.port)
  })
end

-- #######################################################

return alert_port_too_many_macs
