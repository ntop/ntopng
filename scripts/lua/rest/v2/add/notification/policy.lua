--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

--
-- Add a notification policy: the notifications matching the condition (type, minimum severity,
-- categories, host pools, active monitoring hosts, tags; an empty list is no filter) are
-- delivered to the recipients.
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"csrf":"...",
--   "policy_name":"Critical to Ops","policy_notifications_type":"alerts",
--   "policy_minimum_severity":"7","policy_labels":"3","policy_recipients":"1,2"}'
--   "http://localhost:3000/lua/rest/v2/add/notification/policy.lua"
--

-- lua_utils: the validation of the recipients loads the channel modules, which require it
require "lua_utils"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local notification_policies = require "notification_policies"
local recipients_rest_utils = require "recipients_rest_utils"

local res = notification_policies.add_policy(recipients_rest_utils.parse_policy(_POST))

if res.status ~= "OK" then
   rest_utils.answer(rest_utils.consts.err.invalid_args, res.error)
   return
end

rest_utils.answer(rest_utils.consts.success.ok, { policy_id = res.policy_id })
