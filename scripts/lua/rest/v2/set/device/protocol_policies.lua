--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils    = require "rest_utils"
local presets_utils = require "presets_utils"
local json          = require "dkjson"

--
-- Save device protocol policies (bulk update).
-- POST body (JSON): { "device_type": "0", "policies": [{"proto_id":"123","client_action":"1","server_action":"0"}] }
--

local rc  = rest_utils.consts.success.ok
local res = {}

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local body = _POST["payload"] or ""
local data = json.decode(body) or {}

local device_type = tostring(data.device_type or _POST["device_type"] or "")
local policies    = data.policies or {}

if isEmptyString(device_type) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

interface.select(ifname)
presets_utils.init()

for _, entry in ipairs(policies) do
   local proto_id      = tostring(entry.proto_id or "")
   local client_action = tostring(entry.client_action or presets_utils.DEFAULT_ACTION)
   local server_action = tostring(entry.server_action or presets_utils.DEFAULT_ACTION)

   if not isEmptyString(proto_id) then
      presets_utils.updateDeviceProto(device_type, "client", proto_id, client_action)
      presets_utils.updateDeviceProto(device_type, "server", proto_id, server_action)
   end
end

presets_utils.reloadDevicePolicies(device_type)

rest_utils.answer(rc, res)
