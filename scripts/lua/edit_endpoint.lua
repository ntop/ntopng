--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local notification_configs = require("notification_configs")
local rest_utils = require "rest_utils"
local auth = require "auth"

local notifications_manager = require("notifications_manager");

-- ################################################

if not auth.has_capability(auth.capabilities.notifications) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- ################################################

local action = _POST["action"]

sendHTTPContentTypeHeader('application/json')

local endpoint_conf_name = _POST["endpoint_conf_name"]
local response = {}

if (action == "add") then

    local endpoint_conf_type = _POST["endpoint_conf_type"]
    response.result = notification_configs.add_config(endpoint_conf_type, endpoint_conf_name, _POST)

    -- tell to the notification manager that an endpoint has been created
    if (response.result.status == "OK") then
        -- dismiss the notification about the endpoint creation
        local NOTIFICATION_ID = 15 -- see defined_notifications.lua
        notifications_manager.dismiss_notification(NOTIFICATION_ID)
        -- save the endpoint name
        ntop.setCache(notification_configs.LAST_ENDPOINT_NAME_CREATED_CACHE_KEY, endpoint_conf_name)
    end

elseif (action == "edit") then
    response.result = notification_configs.edit_config(endpoint_conf_name, _POST)
elseif (action == "remove") then
    response.result = notification_configs.delete_config(endpoint_conf_name)
end

print(json.encode(response))
