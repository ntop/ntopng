--
-- (C) 2013-20 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path

require ("lua_utils")
local dkjson = require("dkjson")
local notification_manager = require("notifications_manager")

sendHTTPHeader('application/json')

local result = {success = false}
local notification_id = _POST["notification_id"]

-- check if the notification id is significan
if isEmptyString(notification_id) then
    result.error = "The notification ID is null!"
    print(dkjson.encode(result))
    return
end

-- try to dismiss the notification
local success, message = notification_manager.dismiss_notification(notification_id)
result.success = success

if not success then
    result.error = message
else
    result.message = message
end

-- tell the result to the web client
print(dkjson.encode(result))