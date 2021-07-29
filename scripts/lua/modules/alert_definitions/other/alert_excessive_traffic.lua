--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local json = require("dkjson")
local alert_creators = require "alert_creators"
local format_utils = require "format_utils"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_excessive_traffic = classes.class(alert)

-- ##############################################

alert_excessive_traffic.meta = {
  alert_key = other_alert_keys.alert_excessive_traffic,
  i18n_title = "excessive_traffic.title",
  icon = "fas fa-fw fa-arrow-circle-up",
  entities = {
    alert_entities.interface,
    alert_entities.network 
  },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param metric Same as `alert_subtype`
-- @param value A number indicating the measure which crossed the threshold
-- @param operator A string indicating the operator used when evaluating the threshold, one of "gt", ">", "<"
-- @param threshold A number indicating the threshold compared with `value`  using operator
-- @return A table with the alert built
function alert_excessive_traffic:init(host, traffic_type, value, unit)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      host = host,
      traffic_type = traffic_type,
      value = value,
      unit = unit,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_excessive_traffic.format(ifid, alert, alert_type_params)
  local alert_consts = require("alert_consts")

  return i18n("excessive_traffic.alert.description", {
		 host = alert_type_params.host,
		 traffic_type = alert_type_params.traffic_type,
		 value = alert_type_params.value,
		 unit = alert_type_params.unit,
  })
end

-- #######################################################

return alert_excessive_traffic
