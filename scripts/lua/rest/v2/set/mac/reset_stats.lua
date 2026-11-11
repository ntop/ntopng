--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Resets the traffic counters of a MAC address (administrators). JSON POST with the CSRF token.
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": 0, "host": "AA:BB:CC:DD:EE:FF"}' http://localhost:3000/lua/rest/v2/set/mac/reset_stats.lua
--

require "http_lint"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ifid = _POST["ifid"]
local mac = _POST["host"]

if isEmptyString(ifid) or isEmptyString(mac) or not isMacAddress(mac) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

interface.select(tostring(ifid))
if tostring(interface.getId()) ~= tostring(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

if not interface.resetMacStats(mac) then
   rest_utils.answer(rest_utils.consts.err.not_found)
   return
end

rest_utils.answer(rest_utils.consts.success.ok)
