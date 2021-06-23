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

local alert_broadcast_domain_too_large = classes.class(alert)

-- ##############################################

alert_broadcast_domain_too_large.meta = {
   alert_key = other_alert_keys.alert_broadcast_domain_too_large,
   i18n_title = "alerts_dashboard.broadcast_domain_too_large",
   icon = "fas fa-fw fa-sitemap",
   entities = {
      alert_entities.mac
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_param The first alert param
-- @param another_param The second alert param
-- @return A table with the alert built
function alert_broadcast_domain_too_large:init(src_mac, dst_mac, vlan, spa, tpa)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      src_mac = src_mac, dst_mac = dst_mac,
      spa = spa, tpa = tpa, vlan_id = vlan,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_broadcast_domain_too_large.format(ifid, alert, alert_type_params)
   return(i18n("alert_messages.broadcast_domain_too_large", {
      src_mac = alert_type_params.src_mac,
      src_mac_url = getMacUrl(alert_type_params.src_mac),
      dst_mac = alert_type_params.dst_mac,
      dst_mac_url = getMacUrl(alert_type_params.dst_mac),
      spa = alert_type_params.spa,
      spa_url = getHostUrl(alert_type_params.spa, alert_type_params.vlan_id),
      tpa = alert_type_params.tpa,
      tpa_url = getHostUrl(alert_type_params.tpa, alert_type_params.vlan_id),
       }) .. " <i class=\"fa fa-sm fa-info-circle\" title=\"".. i18n("alert_messages.broadcast_domain_info") .."\"></i>")
end

-- #######################################################

return alert_broadcast_domain_too_large
