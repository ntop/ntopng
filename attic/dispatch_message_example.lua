--
-- (C) 2023 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/recipients/?.lua;" .. package.path

local debug_dispatch = false

if not debug_dispatch then
  return
end

require "lua_utils"
local recipients = require "recipients"

-- Everything can be added to notification and it's going to be delivered fully to the recipient.
-- To format the message however the user like, please change accordingly format_notification
-- in format_utils.
-- This is the default notification.
local notification = {
  message = "Some kind of message, just an example"
}

traceError(TRACE_NORMAL, TRACE_CONSOLE, "Debugging dispatch_message_example, sending notification to the specific recipients")

-- A list of all available recipients can be retrieved by calling
--    recipients.get_all_recipients(exclude_builtin, include_stats)
recipients.sendMessageByRecipientName(notification, "tg-report")

-- The list of notification_types can be retrieved by calling
--    recipients.get_notification_types()
recipients.sendMessageByNotificationType(notification, "vulnerability_scans")