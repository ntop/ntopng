--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_connection_failed = classes.class(alert)

-- ##############################################

alert_connection_failed.meta = {
   alert_key = flow_alert_keys.flow_alert_connection_failed,
   i18n_title = "flow_checks_config.connection_failed_title",
   icon = "fas fa-fw fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param connection_failed_threshold Threshold, in seconds, for a flow to be considered connection_failed
-- @return A table with the alert built
function alert_connection_failed:init()
  -- Call the parent constructor
  self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_connection_failed.format(ifid, alert, alert_type_params)
  local cli = format_alert_hostname(alert, "cli")
  local srv = format_alert_hostname(alert, "srv")
  
  return i18n("flow_details.connection_failed_descr", { cli = cli, srv = srv })   
end

-- #######################################################

return alert_connection_failed
