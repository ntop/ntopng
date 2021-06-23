--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_process_notification = classes.class(alert)

-- ##############################################

alert_process_notification.meta = {
  alert_key = other_alert_keys.alert_process_notification,
  i18n_title = "alerts_dashboard.process",
  icon = "fas fa-fw fa-truck",
  entities = {
    alert_entities.system
  },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param event_type The string with the type of event
-- @param msg_details The details of the event
-- @return A table with the alert built
function alert_process_notification:init(event_type, msg_details)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
    msg_details = msg_details,
    event_type = event_type,
   }
end

-- #######################################################

function alert_process_notification.format(ifid, alert, alert_type_params)
  if alert_type_params.event_type == "start" then
    return string.format("%s %s", i18n("alert_messages.ntopng_start"), alert_type_params.msg_details)
  elseif alert_type_params.event_type == "stop" then
    return string.format("%s %s", i18n("alert_messages.ntopng_stop"), alert_type_params.msg_details)
  elseif alert_type_params.event_type == "update" then
    return string.format("%s %s", i18n("alert_messages.update"), alert_type_params.msg_details)
  elseif alert_type_params.event_type == "anomalous_termination" then
     return string.format("%s %s", i18n("alert_messages.ntopng_anomalous_termination", {url="https://www.ntop.org/support/need-help-2/need-help/"}), alert_type_params.msg_details)
  end

  return "Unknown Process Event: " .. (alert_type_params.event_type or "")
end

-- #######################################################

return alert_process_notification
