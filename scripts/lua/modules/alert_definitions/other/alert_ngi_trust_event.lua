--
-- (C) 2020-21 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_ngi_trust_event = classes.class(alert)

-- ##############################################

alert_ngi_trust_event.meta = {
  alert_key = other_alert_keys.alert_ngi_trust_event,
  i18n_title = "alerts_dashboard.ngi_trust_event",
  icon = "fas fa-exchange-alt",
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
  return(i18n("alert_messages.ngi_trust_event", {
    mac = alert_type_params.mac, 
    mac_url = getMacUrl(alert_type_params.mac),
  }))
end

-- #######################################################

return alert_ngi_trust_event
