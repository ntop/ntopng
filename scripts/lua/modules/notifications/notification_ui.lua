--
-- (C) 2020 - ntop.org
--
require("lua_utils")
local json = require "dkjson"
local template = require "template_utils"

local notification_ui = {}
notification_ui.__index = notification_ui

NotificationLevels = {
   SUCCESS = {
      icon = "fa-check-circle",
      bg_color = "success",
      title_text_color = "text-dark",
      fill_color = "#28a745",
   },
   INFO = {
      icon = "fa-info-circle",
      bg_color = "info",
      title_text_color = "text-white",
      fill_color = "#17a2b8",
   },
   WARNING = {
      icon = "fa-exclamation-circle",
      bg_color = "warning",
      title_text_color = "text-dark",
      fill_color = "#ffc107",
   },
   DANGER = {
      icon = "fa-exclamation-triangle",
      bg_color = "danger",
      title_text_color = "text-dark",
      fill_color = "#dc3545",
   },
}

notification_ui.NotificationLevels = NotificationLevels

--- Create an instance of an AlertNotification class
-- @param id The notification id
-- @param title The title shows at the top
-- @param description The notification description (its body)
-- @param level Use different style: danger|info|warning|success
-- @param action The link where the notification brings { url = "#", title = "Click Here!"}
-- @return An AlertNotification instance
function notification_ui:create(id, title, description, level, action, dismissable)

   local this = {
       id              = id,
       title           = (title or i18n("info")),
       description     = (description or i18n("description")),
       level           = (level or NotificationLevels.INFO),
       action          = (action or nil),
       dismissable     = dismissable or false
   }

   setmetatable(this, notification_ui)

   return this
end

-- Return the rendered HTML template for the notification
-- to be displayed. The return string can be printed inside the page
-- with the `print` method
function notification_ui:render()

   local context = {
       notification = self
   }

   -- Generate the template from the notification.template file
   return template.gen('pages/components/notification.template', context)
end


return notification_ui
