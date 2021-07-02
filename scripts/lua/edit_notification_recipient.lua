--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path


require "lua_utils"
local json = require("dkjson")
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

if not isAdministratorOrPrintErr() then
   return
end

local response = {}
local recipient_id = _POST["recipient_id"]
local recipient_name = _POST["recipient_name"]
local categories = recipients_rest_utils.parse_check_categories(_POST["recipient_check_categories"])
local minimum_severity = recipients_rest_utils.parse_minimum_severity(_POST["recipient_minimum_severity"])
local bind_to_all_pools = _POST["bind_to_all_pools"] == "true"

if (action == "add") then
   local endpoint_id = _POST["endpoint_id"]
   response.result = recipients.add_recipient(endpoint_id,
					      recipient_name,
					      categories,
					      minimum_severity,
					      bind_to_all_pools,
					      _POST)
elseif (action == "edit") then
   response.result = recipients.edit_recipient(recipient_id,
					       recipient_name,
					       categories,
					       minimum_severity,
					       _POST)
elseif (action == "remove") then
   response.result = recipients.delete_recipient(recipient_id)
elseif (action == "test") then
   local endpoint_id = _POST["endpoint_id"]
   response.result = recipients.test_recipient(endpoint_id, _POST)
else
   traceError(TRACE_ERROR, TRACE_CONSOLE, "Invalid 'action' parameter.")
   response.success = false
   response.message = "Invalid 'action' parameter."
end

print(json.encode(response))
