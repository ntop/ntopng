--
-- (C) 2020 - ntop.org
--
local menu_alert_notifications = {}
local template = require("template_utils")
local alert_notification = require("alert_notification")

local function load_notifications()

    local notifications = {
        --[[ alert_notification:create(
            0, "Test Danger", "Oh gosh! We are in trouble", "danger",
            { url = "/", title = "OK, I got it!"}, 10000, "prefs.lua?tab=ifaces;system_stats.lua"
        ),
        alert_notification:create(1, "Test Warning", "Something bad can happen!", "warning", nil, 0),
        alert_notification:create(2, "Test Success", "Everything is fine!", "info", nil, 2000) ]]
     }

    return notifications
end

function menu_alert_notifications.dispose_notification(notification_id)

    local response = { success = true, message = "Success!"}
    -- TODO: dispose the notification
    return response
end

function menu_alert_notifications.render_notifications()
    -- render the notifications
    print(template.gen('pages/components/notification_container.template', {
        notifications = load_notifications()
    }))
end

return menu_alert_notifications
