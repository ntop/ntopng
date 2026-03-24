--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils    = require "rest_utils"
local presets_utils = require "presets_utils"

--
-- Reset device protocol policies to presets for a given device type.
-- POST: device_type=<id>
--

local rc  = rest_utils.consts.success.ok
local res = {}

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local device_type = _POST["device_type"] or ""

if isEmptyString(device_type) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

interface.select(ifname)
presets_utils.init()
presets_utils.resetDevicePoliciesFromPresets(tonumber(device_type))
presets_utils.reloadDevicePolicies(device_type)

rest_utils.answer(rc, res)
