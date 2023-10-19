--
-- (C) 2019-22 - ntop.org
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
local entities = recipients_rest_utils.parse_check_entities(_POST["recipient_check_entities"])
local host_pools_ids = recipients_rest_utils.parse_host_pools(_POST["recipient_host_pools"])
local am_hosts_ids = recipients_rest_utils.parse_am_hosts(_POST["recipient_am_hosts"])
local minimum_severity = recipients_rest_utils.parse_minimum_severity(_POST["recipient_minimum_severity"])

if (action == "add") then
   local endpoint_id = _POST["endpoint_id"]
   response.result = recipients.add_recipient(endpoint_id,
					      recipient_name,
					      categories,
					      entities,
					      minimum_severity,
					      host_pools_ids,
					      am_hosts_ids,
					      _POST)
elseif (action == "edit") then
   response.result = recipients.edit_recipient(recipient_id,
					       recipient_name,
					       categories,
					       entities,
					       minimum_severity,
					       host_pools_ids,
					       am_hosts_ids,
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
