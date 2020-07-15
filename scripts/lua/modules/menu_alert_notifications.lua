--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_notifications/?.lua;" .. package.path

local menu_alert_notifications = {}
local template = require("template_utils")
local defined_alert_notifications = require("defined_alert_notifications")

--- Returns an array of notification to be displayed as default
--- @return table
function menu_alert_notifications.load_main_notifications()

    local notifications = {}

    -- check if I have to insert the missing geoip notification
    defined_alert_notifications.geo_ip(notifications)
    defined_alert_notifications.temp_working_dir(notifications)
    defined_alert_notifications.contribute(notifications)

    return notifications
end

--- Create a notification container inside the page where to render the alert notifications.
--- @param container_id string The container id attribute
--- @param notifications table A alert_notifications list to render inside the container,
function menu_alert_notifications.render_notifications(container_id, notifications)
    -- render the notifications
    print(template.gen('pages/components/notification_container.template', {
        notifications = notifications,
        container_id = container_id
    }))
end

return menu_alert_notifications
