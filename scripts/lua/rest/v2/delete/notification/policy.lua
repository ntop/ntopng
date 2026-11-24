--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

--
-- Delete a notification policy (its recipients are not deleted).
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"csrf":"...",
--   "policy_id":"0"}' "http://localhost:3000/lua/rest/v2/delete/notification/policy.lua"
--

require "http_lint"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local notification_policies = require "notification_policies"

if not notification_policies.delete_policy(_POST["policy_id"]) then
   rest_utils.answer(rest_utils.consts.err.invalid_args, { type = "policy_not_existing" })
   return
end

rest_utils.answer(rest_utils.consts.success.ok)
