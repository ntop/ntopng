--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
-- ##############################################

local other_alert_keys = require "other_alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"
local format_utils = require "format_utils"

-- ##############################################

local alert_periodic_activity_not_executed = classes.class(alert)

-- ##############################################

alert_periodic_activity_not_executed.meta = {
  alert_key = other_alert_keys.alert_periodic_activity_not_executed,
  i18n_title = "alerts_dashboard.periodic_activity_not_executed",
  icon = "fas fa-fw fa-undo",
  entities = {
    alert_entities.system
  },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param ps_name A string with the name of the periodic activity
-- @param last_queued_time The time when the periodic activity was executed for the last time, as a unix epoch
-- @return A table with the alert built
function alert_periodic_activity_not_executed:init(ps_name, last_queued_time)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      ps_name = ps_name,
      last_queued_time = last_queued_time,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_periodic_activity_not_executed.format(ifid, alert, alert_type_params)
   return(i18n("alert_messages.periodic_activity_not_executed",
	       {
		  script = alert_type_params.ps_name,
		  pending_since = format_utils.formatPastEpochShort(alert_type_params.last_queued_time),
   }))
end

-- #######################################################

return alert_periodic_activity_not_executed
