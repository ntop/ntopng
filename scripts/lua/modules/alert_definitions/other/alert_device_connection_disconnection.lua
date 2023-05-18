--
-- (C) 2019-22 - ntop.org
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

local alert_device_connection_disconnection = classes.class(alert)

-- ##############################################

alert_device_connection_disconnection.meta = {
    alert_key = other_alert_keys.alert_device_connection_disconnection,
    i18n_title = "alerts_dashboard.device_connection_disconnection",
    icon = "fas fa-fw fa-sign-in",
    entities = {alert_entities.mac}
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param device The a string with the name or ip address of the device that connected the network
-- @return A table with the alert built
function alert_device_connection_disconnection:init(device, event)
    -- Call the parent constructor
    self.super:init()

    self.alert_type_params = {
        device = device,
        event = event
    }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_device_connection_disconnection.format(ifid, alert, alert_type_params)
    local event = alert_type_params.event or "connected"

    if event == 'connected' then
        return (i18n("alert_messages.device_has_connected", {
            device = alert_type_params.device,
            device_url = getMacUrl(alert_type_params.device),
            if_name = getInterfaceName(ifid),
            if_url = getInterfaceUrl(ifid),
            exclusion_url = ntop.getHttpPrefix() .. "/lua/pro/admin/edit_device_exclusions.lua"
        }))
    else
        return (i18n("alert_messages.device_has_disconnected", {
            device = alert_type_params.device,
            device_url = getMacUrl(alert_type_params.device),
            if_name = getInterfaceName(ifid),
            if_url = getInterfaceUrl(ifid),
            exclusion_url = ntop.getHttpPrefix() .. "/lua/pro/admin/edit_device_exclusions.lua"
        }))

    end
end

-- #######################################################

return alert_device_connection_disconnection
