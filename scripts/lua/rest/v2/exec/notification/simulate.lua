--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

--
-- Simulate the alerts raised by a check, an ACL, a traffic rule, an SNMP device rule, an active
-- monitoring measurement or an AI policy, with the (not necessarily saved)
-- values of its dialog: stored or not, matching notification policies and notified recipients.
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"csrf":"...",
--   "simulation_source":"check","check_subdir":"host","script_key":"scan_detection"}'
--   "http://localhost:3000/lua/rest/v2/exec/notification/simulate.lua"
--

require "lua_utils"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- Interface of the host pools of the hosts (traffic rules) and SNMP devices
if not isEmptyString(_POST["ifid"]) then
   interface.select(tostring(_POST["ifid"]))
end

local notification_simulation = require "notification_simulation"

local res = notification_simulation.simulate(_POST["simulation_source"], _POST)

if not res then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

rest_utils.answer(rest_utils.consts.success.ok, res)
