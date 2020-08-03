--
-- (C) 2020 - ntop.org
--
require("lua_utils")
local json = require "dkjson"
local template = require "template_utils"

alert_notification = {}
alert_notification.__index = alert_notification

alert_notification_levels = {
   success = {
      icon = "fa-check-circle",
      bg_color = "success",
      title_text_color = "text-dark",
   },
   info = {
      icon = "fa-info-circle",
      bg_color = "info",
      title_text_color = "text-dark",
   },
   warning = {
      icon = "fa-exclamation-circle",
      bg_color = "warning",
      title_text_color = "text-dark",
   },
   danger = {
      icon = "fa-exclamation-triangle",
      bg_color = "danger",
      title_text_color = "text-dark",
   },
}

--- Create an instance of an AlertNotification class
-- @param id The notification id
-- @param title The title shows at the top
-- @param description The notification description (its body)
-- @param level Use different style: danger|info|warning|success
-- @param action The link where the notification brings { url = "#", title = "Click Here!"}
-- @param no_scope A list of pages where the notification won't render
-- @return An AlertNotification instance
function alert_notification:create(id, title, description, level, action, no_scope)

    local this = {
        id              = id,
        title           = (title or i18n("info")),
        description     = (description or i18n("description")),
        level           = (alert_notification_levels[level] or alert_notification_levels.info),
        action          = (action or nil),
        no_scope        = no_scope or "",
    }

    setmetatable(this, alert_notification)

    return this
end

-- Return the rendered HTML template for the notification
-- to be displayed. The return string can be printed inside the page
-- with the `print` method
function alert_notification:render()

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


return alert_notification
