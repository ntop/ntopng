--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

--
-- Delete a notification recipient (not the builtin one). With delete_endpoint=true its
-- connection is deleted too when no other recipient uses it.
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"csrf":"...",
--   "recipient_id":"3","delete_endpoint":"true"}'
--   "http://localhost:3000/lua/rest/v2/delete/notification/recipient.lua"
--

-- http_lint (validates the params, loads ntop_utils: isAdministrator, isEmptyString). No lua_utils:
-- reading/deleting recipients does not load the channel modules
require "http_lint"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local endpoints = require "endpoints"
local recipients = require "recipients"

local recipient_id = tonumber(_POST["recipient_id"])
local recipient = recipient_id and recipients.get_recipient(recipient_id)

if not recipient or (recipient.endpoint_conf and recipient.endpoint_conf.builtin) then
   rest_utils.answer(rest_utils.consts.err.invalid_args, { type = "endpoint_recipient_not_existing" })
   return
end

if not recipients.delete_recipient(recipient_id) then
   rest_utils.answer(rest_utils.consts.err.internal_error)
   return
end

local endpoint_deleted = false
if _POST["delete_endpoint"] == "true" and #recipients.get_recipients_by_conf(recipient.endpoint_id) == 0 then
   endpoint_deleted = (endpoints.delete_config(recipient.endpoint_id).status == "OK")
end

rest_utils.answer(rest_utils.consts.success.ok, { endpoint_deleted = endpoint_deleted })
