--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local json = require "dkjson"
local menu_alert_notifications = require("menu_alert_notifications")

sendHTTPContentTypeHeader('application/json')

local response
local action = _POST["action"] or nil

-- if the action is not valid then shows an error message
if isEmptyString(action) then
    print(json.encode({success = false, message = "The action is not valid!"}))
    return
end

-- otherwise handle the action
if action == "disposed" then
    local notification_id = _POST["notification_id"]
    response = menu_alert_notifications.dispose_notification(notification_id)
end

print(json.encode(response))
