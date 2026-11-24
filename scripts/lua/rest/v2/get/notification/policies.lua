--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

--
-- List the notification policies, with the names of their recipients.
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/notification/policies.lua"
--

require "http_lint"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local recipients = require "recipients"
local notification_policies = require "notification_policies"

local recipient_names = {}
for _, recipient in ipairs(recipients.get_all_recipients(true --[[ exclude builtin ]])) do
   recipient_names[recipient.recipient_id] = recipient.recipient_name
end

local res = {}
for _, policy in ipairs(notification_policies.get_all_policies()) do
   local policy_recipients = {}

   for _, recipient_id in ipairs(policy.recipient_ids) do
      policy_recipients[#policy_recipients + 1] = { recipient_id = recipient_id, recipient_name = recipient_names[recipient_id] }
   end

   policy.recipients = policy_recipients
   res[#res + 1] = policy
end

rest_utils.answer(rest_utils.consts.success.ok, res)
