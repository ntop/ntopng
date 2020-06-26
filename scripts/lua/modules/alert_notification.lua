--
-- (C) 2020 - ntop.org
--
require("lua_utils")
local json = require "dkjson"
local template = require "template_utils"

Alert_notification = {}
Alert_notification.__index = Alert_notification

Alert_notification_levels = {
    danger = {
        icon = "fa-times-circle",
        bg_color = "danger",
        title_text_color = "text-white",
        body_text_color = "text-white",
    },
    info = {
        icon = "fa-info-circle",
        bg_color = "info",
        title_text_color = "text-white",
        body_text_color = "text-white",
    },
    warning = {
        icon = "fa-exclamation-circle",
        bg_color = "warning",
        title_text_color = "text-dark",
        body_text_color = "text-dark",
    },
    success = {
        icon = "fa-check-circle",
        bg_color = "success",
        title_text_color = "text-white",
        body_text_color = "text-white",
    },
}

--- Create an instance of an AlertNotification class
-- @param id The notification id
-- @param title The title shows at the top
-- @param description The notification description (its body)
-- @param level Use different style: danger|info|warning|success
-- @param action The link where the notification brings { url = "#", title = "Click Here!"}
-- @param delay_to_fade The delay to fade in milliseconds
-- @param no_scope A list of pages where the notification won't render
-- @return An AlertNotification instance
function Alert_notification:create(id, title, description, level, action, delay_to_fade, no_scope)

    local this = {
        id              = id,
        title           = (title or 'Ntopng Notification'),
        description     = (description or 'short description'),
        level           = (Alert_notification_levels[level] or Alert_notification_levels.info),
        action          = (action or nil),
        delay_to_fade   = delay_to_fade or 0,
        no_scope        = no_scope or ""
    }

    setmetatable(this, Alert_notification)

    return this
end

-- Return the rendered HTML template for the notification
-- to be displayed. The return string can be printed inside the page
-- with the `print` method
function Alert_notification:render()

    local context = {
        style = self.level,
        content = {
            title   = self.title,
            body    = self.description,
            action  = self.action
        },
        model = self
    }

    -- Generate the template from the notification.template file
    return template.gen('pages/components/notification.template', context)
end


return Alert_notification