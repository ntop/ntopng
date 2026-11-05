--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Restart the traffic recording (n2disk) of an interface after a failure (administrators,
-- n2disk installed, recording enabled and managed by ntopng, n2disk not running).
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "0"}' http://localhost:3000/lua/rest/v2/set/interface/recording/restart.lua
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
if tostring(interface.getId()) ~= tostring(ifid) or interface.isView() then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

local master_ifid = interface.getMasterInterfaceId()
if recording_utils.getCurrentTrafficRecordingProvider(master_ifid) ~= "ntopng"
   or not recording_utils.isEnabled(master_ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

-- Already running: nothing to do (as the old status page)
if not recording_utils.isActive(master_ifid) then
   recording_utils.restart(master_ifid)
end

rest_utils.answer(rest_utils.consts.success.ok)
