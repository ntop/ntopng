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

local alert_mac_ip_association_change = classes.class(alert)

-- ##############################################

alert_mac_ip_association_change.meta = {
  alert_key = other_alert_keys.alert_mac_ip_association_change,
  i18n_title = "alerts_dashboard.mac_ip_association_change",
  icon = "fas fa-fw fa-exchange-alt",
  entities = {
    alert_entities.mac
  },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param device The name of the device that changed MAC
-- @param ip The ip address of the device that changed MAC
-- @param old_mac The old MAC
-- @param new_mac The new MAC
-- @return A table with the alert built
function alert_mac_ip_association_change:init(device, ip, old_mac, new_mac)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
    device = device,
    ip = ip,
    old_mac = old_mac,
    new_mac = new_mac,
   }
end

-- #######################################################

function alert_mac_ip_association_change.format(ifid, alert, alert_type_params)
  return(i18n("alert_messages.mac_ip_association_change", {
    new_mac = alert_type_params.new_mac, old_mac = alert_type_params.old_mac,
    ip = alert_type_params.ip, new_mac_url = getMacUrl(alert_type_params.new_mac), old_mac_url = getMacUrl(alert_type_params.old_mac)
  }))
end

-- #######################################################

return alert_mac_ip_association_change
