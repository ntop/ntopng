--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local host_alert_keys = require "host_alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local alert_creators = require "alert_creators"
local format_utils = require "format_utils"
local json = require("dkjson")
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local host_alert_flow_flood = classes.class(alert)

-- ##############################################

host_alert_flow_flood.meta = {
  alert_key = host_alert_keys.host_alert_flow_flood,
  i18n_title = "alerts_dashboard.flow_flood",
  icon = "fas fa-fw fa-life-ring",
  has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_param The first alert param
-- @param another_param The second alert param
-- @return A table with the alert built
function host_alert_flow_flood:init(metric, value, operator, threshold)
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
function host_alert_flow_flood.format(ifid, alert, alert_type_params)
  local alert_consts = require("alert_consts")
  local entity = alert_consts.formatHostAlert(ifid, alert["ip"], alert["vlan_id"])
  local value = alert_type_params.value
  local i18n_key

  if alert_type_params.is_attacker then
    i18n_key = "alert_messages.flow_flood_attacker"
  else
    i18n_key = "alert_messages.flow_flood_victim"
  end

  return i18n(i18n_key, {
    entity = entity,
    value = string.format("%u", math.ceil(value)),
    threshold = alert_type_params.threshold,
  })
end

-- #######################################################

return host_alert_flow_flood
