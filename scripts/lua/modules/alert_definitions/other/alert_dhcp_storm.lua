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

local alert_dhcp_storm = classes.class(alert)

-- ##############################################

alert_dhcp_storm.meta = {
  alert_key = other_alert_keys.alert_dhcp_storm,
  i18n_title = "alerts_dashboard.dhcp_storm",
  icon = "fas fa-fw fa-ghost",
  entities = {
     alert_entities.interface,
  },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_dhcp_storm:init(epoch, dhcp_num_pkts)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      epoch = epoch,
      dhcp_num_pkts = dhcp_num_pkts
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_dhcp_storm.format(ifid, alert, alert_type_params)
  return(i18n("alerts_dashboard.dhcp_storm_detected_description", {
    epoch = formatEpoch(alert_type_params.epoch),
    entity = getInterfaceName(ifid),
    dhcp_num_pkts = alert_type_params.dhcp_num_pkts,
  }))
end

-- #######################################################

return alert_dhcp_storm
