--
-- (C) 2019-24 - ntop.org
--
-- ##############################################
local other_alert_keys = require "other_alert_keys"
local alert_creators = require "alert_creators"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_acl_violation_arp = classes.class(alert)

-- ##############################################

alert_acl_violation_arp.meta = {
    alert_key = other_alert_keys.alert_acl_violation_arp,
    i18n_title = "alerts_dashboard.access_control_list_arp",
    icon = "fas fa-fw fa-sign-in",
    entities = {
       alert_entities.mac
    },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param device The a string with the name or ip address of the device that connected the network
-- @return A table with the alert built
function alert_acl_violation_arp:init(device, num_new_flows)
    -- Call the parent constructor
    self.super:init()

    self.alert_type_params = {
        device = device,
        num_new_flows = num_new_flows
    }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_acl_violation_arp.format(ifid, alert, alert_type_params)
   local href = ntop.getHttpPrefix() .. '/lua/pro/admin/access_control_list.lua'
    return i18n('alerts_dashboard.alert_acl_violation_arp_descr', { num = alert_type_params.num_new_flows, href = href })
end

-- #######################################################

return alert_acl_violation_arp
