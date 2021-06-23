--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local dirs = ntop.getDirs()
local other_alert_keys = require "other_alert_keys"

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local format_utils = require "format_utils"

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_slow_periodic_activity = classes.class(alert)

-- ##############################################

alert_slow_periodic_activity.meta = {
  alert_key = other_alert_keys.alert_slow_periodic_activity,
  i18n_title = "alerts_dashboard.slow_periodic_activity",
  icon = "fas fa-fw fa-undo",
  entities = {
    alert_entities.system
  },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param ps_name A string with the name of the periodic activity
-- @param max_duration_ms The maximum duration taken by this periodic activity to run, in milliseconds
-- @return A table with the alert built
function alert_slow_periodic_activity:init(ps_name, max_duration_ms)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      ps_name = ps_name,
      max_duration_ms = max_duration_ms,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_slow_periodic_activity.format(ifid, alert, alert_type_params)
  local max_duration

  max_duration = format_utils.secondsToTime(alert_type_params.max_duration_ms / 1000)

  return(i18n("alert_messages.slow_periodic_activity", {
    script = alert_type_params.ps_name,
    max_duration = max_duration,
  }))
end

return alert_slow_periodic_activity
