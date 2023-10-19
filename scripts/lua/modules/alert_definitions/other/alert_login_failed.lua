--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_login_failed = classes.class(alert)

-- ##############################################

alert_login_failed.meta = {
  alert_key = other_alert_keys.alert_login_failed,
  i18n_title = "alerts_dashboard.login_failed",
  icon = "fas fa-fw fa-sign-in",
  entities = {
    alert_entities.user,
    alert_entities.system
  },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_login_failed:init()
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {}
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_login_failed.format(ifid, alert, alert_type_params)
  return(i18n("user_activity.login_not_authorized", {
    user = alert.user,
  }))
end

-- #######################################################

return alert_login_failed
