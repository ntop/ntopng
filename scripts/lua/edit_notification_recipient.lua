--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/recipients/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local plugins_utils = require "plugins_utils"
local notification_recipients = require("notification_recipients")
-- local recipients = require "recipients"
-- local recipients_instance = recipients:create()

local action = _POST["action"]

sendHTTPContentTypeHeader('application/json')

if not haveAdminPrivileges() then
   return
end

local response = {}
local recipient_name = _POST["recipient_name"]
-- local recipient_id = _POST["recipient_id"]

if (action == "add") then
   local endpoint_conf_name = _POST["endpoint_conf_name"]
   response.result = notification_recipients.add_recipient(endpoint_conf_name, recipient_name, _POST)
   -- response.result = recipients_instance:add_recipient(endpoint_conf_name, recipient_name, _POST)
elseif (action == "edit") then
   response.result = notification_recipients.edit_recipient(recipient_name, _POST)
   -- response.result = recipients_instance:edit_recipient(recipient_id, recipient_name, _POST)
elseif (action == "remove") then
   response.result = notification_recipients.delete_recipient(recipient_name)
   -- response.result = recipients_instance:delete_recipient(recipient_id)
elseif (action == "test") then
   local endpoint_conf_name = _POST["endpoint_conf_name"]
   response.result = notification_recipients.test_recipient(endpoint_conf_name, recipient_name, _POST)
   -- response.result = recipients_instance:test_recipient(endpoint_conf_name, _POST)
else
   traceError(TRACE_ERROR, TRACE_CONSOLE, "Invalid 'action' parameter.")
   response.success = false
   response.message = "Invalid 'action' parameter."
end

print(json.encode(response))
