--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_notifications/?.lua;" .. package.path

local page_utils = require("page_utils")
local template = require("template_utils")
local defined_notifications = require("defined_notifications")

-- Redis Key used to store the notification status
local REDIS_KEY = "ntopng.user.%s.dismissised_notices.notification_%d"
local notifications_manager = {}

local function notification_has_been_dismissed(notification_id)
    return ntop.getPref(string.format(REDIS_KEY, _SESSION['user'], notification_id)) == "1"
end

--- Returns an array of notification to be displayed inside the pages
--- @return table
function notifications_manager.load_main_notifications()

    local container = {}
    local current_page = page_utils.get_active_entry()
    local curent_subpage = _GET['page']

    for _, notification in ipairs(defined_notifications) do

        -- if the current page is excluded then don't show the notification
        if (table.contains(notification.excluded_pages, current_page)) then
            goto continue
        end

        -- if we are in a excluded subpage then don't show the notification
        local excluded_subpages = notification.excluded_subpages or {[current_page] = {}}
        if (table.contains(excluded_subpages, curent_subpage)) then
            goto continue
        end

        -- check if the notification have the predicate function
        if (notification.predicate == nil) then
            traceError(TRACE_ERROR, TRACE_CONSOLE, "The notification '".. notification.id .. "' doesn't have a predicate function!")
            goto continue
        end

        -- has the notification be dissmissed by the user?
        local dismissed = (notification.dismissable and notification_has_been_dismissed(notification.id))
        if (dismissed) then goto continue end

        -- check if we can add the notification inside the page
        local subpages = notification.subpages or {[current_page] = {}}
        local can_add = (table.len(notification.pages) == 0) or (
            table.contains(notification.pages, current_page)) or (table.contains(subpages, curent_subpage))

        if can_add then
            -- check the predicate function
            notification.predicate(notification, container)
        end

        -- used to jump to the next notification
        ::continue::
    end

    return container
end

--- Dismiss the notification if the notification is is valid, otherwise return an error
--- @param notification_id string The notification to dismiss
--- @return (boolean, string) True if the notification has been dismissed
function notifications_manager.dismiss_notification(notification_id)

    -- Check if the notification id is valid in order to prevent to set not valid
    -- REDIS keys
    local compare = (function(n) return n.id == notification_id end)
    if not (table.contains(defined_notifications, notification_id, compare)) then
        traceError(TRACE_ERROR, TRACE_CONSOLE, "The passed notification ID is not valid!")
        return false, "Not a valid notification ID!"
    end

    -- Dismiss the notification
    ntop.setPref(string.format(REDIS_KEY, _SESSION['user'], notification_id), "1")
    return true, "Success"
end

--- Create a notification container inside the page where to render the alert notifications.
--- @param container_id string The container id attribute
--- @param notifications table A alert_notifications list to render inside the container,
function notifications_manager.render_notifications(container_id, notifications)
    -- render the notifications
    print(template.gen('pages/components/notification_container.template', {
        notifications = notifications,
        container_id = container_id
    }))
end

return notifications_manager
