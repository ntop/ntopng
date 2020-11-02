--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/recipients/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local plugins_utils = require "plugins_utils"
local pools = require "pools"
local notification_configs = require("notification_configs")
local recipients_rest_utils = require "recipients_rest_utils"
local recipients = require "recipients"
local rest_utils = require "rest_utils"
local auth = require "auth"

-- ################################################

if not auth.has_capability(auth.capabilities.notifications) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- ################################################

local action = _POST["action"]

sendHTTPContentTypeHeader('application/json')

if not haveAdminPrivileges() then
   return
end

local response = {}
local recipient_id = _POST["recipient_id"]
local recipient_name = _POST["recipient_name"]
local categories = recipients_rest_utils.parse_user_script_categories(_POST["recipient_user_script_categories"])
local minimum_severity = recipients_rest_utils.parse_minimum_severity(_POST["recipient_minimum_severity"])

if (action == "add") then
   local endpoint_conf_name = _POST["endpoint_conf_name"]
   response.result = recipients.add_recipient(endpoint_conf_name,
					      recipient_name,
					      categories,
					      minimum_severity,
                     _POST)

   -- tell to the notification manager that a recipient has been created
   if (response.result.status == "OK") then
      -- save recipient name inside the cache
      ntop.setCache(recipients.LAST_RECIPIENT_NAME_CREATED_CACHE_KEY, recipient_name)
      -- delete the name of the last endpoint created from the cache
      ntop.delCache(notification_configs.LAST_ENDPOINT_NAME_CREATED_CACHE_KEY)
      -- delete previous cache about pool binding
      ntop.delCache(pools.RECIPIENT_BOUND_CACHE_KEY)
  end

elseif (action == "edit") then
   response.result = recipients.edit_recipient(recipient_id,
					       recipient_name,
					       categories,
					       minimum_severity,
					       _POST)
elseif (action == "remove") then
   response.result = recipients.delete_recipient(recipient_id)
elseif (action == "test") then
   local endpoint_conf_name = _POST["endpoint_conf_name"]
   response.result = recipients.test_recipient(endpoint_conf_name, _POST)
else
   traceError(TRACE_ERROR, TRACE_CONSOLE, "Invalid 'action' parameter.")
   response.success = false
   response.message = "Invalid 'action' parameter."
end

print(json.encode(response))
