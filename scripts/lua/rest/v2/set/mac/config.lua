--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

--
-- Saves the settings of a MAC address (administrators): alias (empty: removed), device type and
-- host pool (not on view interfaces). JSON POST with the CSRF token.
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": 0, "host": "AA:BB:CC:DD:EE:FF", "custom_name": "printer", "device_type": 1, "pool": 0}' http://localhost:3000/lua/rest/v2/set/mac/config.lua
--

require "http_lint"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ifid = _POST["ifid"]
local mac = _POST["host"]
local device_type = tonumber(_POST["device_type"])
local pool_id = tonumber(_POST["pool"])
local custom_name = _POST["custom_name"]

if isEmptyString(ifid) or isEmptyString(mac) or not isMacAddress(mac) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

interface.select(tostring(ifid))
if tostring(interface.getId()) ~= tostring(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

require "lua_utils_get"
local discover = require "discover_utils"
local host_pools = require "host_pools"
local pools = host_pools:create()

-- Device type: one of the known ids (discover_utils)
if (device_type ~= nil) and isEmptyString(discover.id2devtype(device_type)) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

if (pool_id ~= nil) and ((interface.getStats().isView) or (pools:get_pool(pool_id) == nil)) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

if custom_name ~= nil then
   setHostAltName(mac, custom_name)
end

if device_type ~= nil then
   setCustomDeviceType(mac, device_type)
   ntop.setMacDeviceType(mac, device_type, true --[[ overwrite ]])
end

if pool_id ~= nil then
   local cur = pools:get_pool_by_member(mac)
   if (cur == nil) or (cur["pool_id"] ~= pool_id) then
      if not pools:bind_member(mac, pool_id) then
         rest_utils.answer(rest_utils.consts.err.internal_error)
         return
      end
   end
end

rest_utils.answer(rest_utils.consts.success.ok)
