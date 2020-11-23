--
-- (C) 2020 - ntop.org
--
require("lua_utils")
local json = require "dkjson"
local template = require "template_utils"

local ToastUI = {}
ToastUI.__index = ToastUI
ToastLevels = {
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

ToastUI.ToastLevels = ToastLevels

--- Create an instance of an Alerttoast class
-- @param id The toast id
-- @param title The title shows at the top
-- @param description The toast description (its body)
-- @param level Use different style: danger|info|warning|success
-- @param action The link where the toast brings { url = "#", title = "Click Here!"}
-- @return A Toast UI instance
function ToastUI:new(id, title, description, level, action, dismissable)

   local this = {
       id              = id,
       title           = (title or i18n("info")),
       description     = (description or i18n("description")),
       level           = (level or ToastLevels.INFO),
       action          = (action or nil),
       dismissable     = dismissable or false
   }

   setmetatable(this, ToastUI)

   return this
end

-- Return the rendered HTML template for the toast
-- to be displayed. The return string can be printed inside the page
-- with the `print` method
function ToastUI:render()

   local context = { toast = self }

   -- Generate the template from the toast.template file
   return template.gen('pages/components/toast.template', context)
end


return ToastUI
