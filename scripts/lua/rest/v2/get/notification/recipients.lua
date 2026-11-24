--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path

--
-- Notification recipients (builtin alert DB store included) with their filters and
-- delivery stats. Raw values only.
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/notification/recipients.lua"
--

-- http_lint (validates the params, loads ntop_utils: isAdministrator, isEmptyString). No lua_utils:
-- reading/deleting recipients does not load the channel modules
require "http_lint"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local recipients = require "recipients"
local notification_policies = require "notification_policies"

local policies = notification_policies.get_all_policies()
local res = {}

for _, r in ipairs(recipients.get_all_recipients(false, true --[[ stats ]])) do
   local recipient_id = r.recipient_id
   local endpoint_conf = r.endpoint_conf or {}
   -- The policies delivering to the recipient
   local recipient_policies = {}

   for _, policy in ipairs(policies) do
      if table.contains(policy.recipient_ids, recipient_id) then
         recipient_policies[#recipient_policies + 1] = { policy_id = policy.policy_id, name = policy.name }
      end
   end

   res[#res + 1] = {
      recipient_id = recipient_id,
      recipient_name = r.recipient_name,
      endpoint_id = tonumber(r.endpoint_id) or r.endpoint_id,
      endpoint_key = r.endpoint_key,
      endpoint_conf_name = r.endpoint_conf_name,
      builtin = endpoint_conf.builtin or false,
      -- Builtin recipient only: minimum severity of the stored alerts
      minimum_severity = r.minimum_severity,
      policies = recipient_policies,
      recipient_params = r.recipient_params or {},
      stats = r.stats,
   }
end

rest_utils.answer(rest_utils.consts.success.ok, res)
