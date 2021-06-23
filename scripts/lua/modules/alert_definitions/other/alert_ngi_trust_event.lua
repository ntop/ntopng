--
-- (C) 2020-21 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"
local format_utils = require "format_utils"

-- ##############################################

local alert_ngi_trust_event = classes.class(alert)

-- ##############################################

alert_ngi_trust_event.meta = {
  alert_key = other_alert_keys.alert_ngi_trust_event,
  i18n_title = "alerts_dashboard.ngi_trust_event",
  icon = "fas fa-fw fa-home",
  entities = {},
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param device The name of the device
-- @param mac The device MAC
-- @return A table with the alert built
function alert_ngi_trust_event:init(device, mac)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      device = device,
      mac = mac,
   }
end

-- #######################################################

function alert_ngi_trust_event.format(ifid, alert, alert_type_params)
   local i18n_key = "alert_messages.ngi_trust_event"
   if alert_type_params.in_alarm == 0 then
      i18n_key = "alert_messages.ngi_trust_event_released"
   end

   return(i18n(i18n_key, {
      mac = alert_type_params.mac_address, 
      mac_url = getMacUrl(alert_type_params.mac_address),
      time = format_utils.formatEpoch(math.floor(alert_type_params.time_epoch)),
      last_state = alert_type_params.last_state,
      state_unchanged_since = format_utils.formatEpoch(math.floor(alert_type_params.state_unchanged_since)),
      abnormality_grade = alert_type_params.abnormality_grade,
   }))
end

-- #######################################################

return alert_ngi_trust_event
