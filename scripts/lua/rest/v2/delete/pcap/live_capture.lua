--
-- (C) 2013-26 - ntop.org
--
-- Stops a live capture (POST { ifid, capture_id }), administrators only
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "http_lint"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ifid = _POST["ifid"]
local capture_id = tonumber(_POST["capture_id"])

if isEmptyString(ifid) or not capture_id then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

interface.select(tostring(ifid))
if tostring(interface.getId()) ~= tostring(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

interface.stopLiveCapture(capture_id)

rest_utils.answer(rest_utils.consts.success.ok)
