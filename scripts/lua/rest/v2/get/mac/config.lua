--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

--
-- Settings of a MAC address (administrators): alias, device type and host pool, with the pools
-- that can be chosen (none on view interfaces: the pool is set on the viewed ones).
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/mac/config.lua?ifid=0&host=AA:BB:CC:DD:EE:FF"
--

require "http_lint"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ifid = _GET["ifid"]
local mac = _GET["host"]

if isEmptyString(ifid) or isEmptyString(mac) or not isMacAddress(mac) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

interface.select(ifid)
if tostring(interface.getId()) ~= tostring(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

require "lua_utils_get"
local host_pools = require "host_pools"
local pools = host_pools:create()
local mac_info = interface.getMacInfo(mac)
local pool = pools:get_pool_by_member(mac)
local is_view = interface.getStats().isView or false

local pool_list
if not is_view then
   pool_list = {}
   for _, p in pairs(pools:get_all_pools() or {}) do
      pool_list[#pool_list + 1] = { id = p.pool_id, name = p.name }
   end
   table.sort(pool_list, function(a, b) return a.id < b.id end)
end

rest_utils.answer(rest_utils.consts.success.ok, {
   alias = getHostAltName(mac),
   device_type = mac_info and mac_info.devtype or tonumber(getCustomDeviceType(mac)) or 0,
   pool_id = pool and pool["pool_id"] or pools.DEFAULT_POOL_ID,
   pools = pool_list,
   is_nedge = (ntop.isnEdge and ntop.isnEdge()) or false,
})
