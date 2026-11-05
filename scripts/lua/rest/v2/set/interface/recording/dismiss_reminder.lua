--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Hide the "external traffic recording providers detected" notice of an interface
-- (administrators, n2disk installed). Replaces the old traffic_recording_config.lua.
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "0"}' http://localhost:3000/lua/rest/v2/set/interface/recording/dismiss_reminder.lua
--

-- http_lint: validates the JSON body (CSRF included) into _POST
require "http_lint"
require "ntop_utils"
local rest_utils = require "rest_utils"
local recording_utils = require "recording_utils"

if not recording_utils.isAvailable() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ifid = _POST["ifid"]
if isEmptyString(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end
interface.select(ifid)
if tostring(interface.getId()) ~= tostring(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

recording_utils.dismissExternalProvidersReminder(interface.getId())

rest_utils.answer(rest_utils.consts.success.ok)
