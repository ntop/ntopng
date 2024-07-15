--
-- (C) 2019-24 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_exporters_limit_exceeded = classes.class(alert)

alert_exporters_limit_exceeded.meta = {
  alert_key = other_alert_keys.alert_exporters_limit_exceeded,
  i18n_title = "internals.exporters_limit_exceeded",
  icon = "fas fa-fw fa-exclamation-triangle",
  entities = {
     alert_entities.system,
  },
}

-- ##############################################

function alert_exporters_limit_exceeded:init(system_error_msg)
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
function alert_exporters_limit_exceeded.format(ifid, alert, alert_type_params)
   return(i18n("alert_messages.exporters_limit_exceeded"))
end

-- #######################################################

return alert_exporters_limit_exceeded
