--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

--
-- Overview of an active MAC address (MAC details page): identity, device, pool and traffic
-- counters, raw values. counters=true: only the counters (polled by the page).
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/mac/overview.lua?ifid=0&host=AA:BB:CC:DD:EE:FF"
--

require "http_lint"
local rest_utils = require "rest_utils"

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

local mac_info = interface.getMacInfo(mac)

if mac_info == nil then
   rest_utils.answer(rest_utils.consts.err.not_found)
   return
end

-- The counters updated live
local counters = {
   ["seen.first"] = mac_info["seen.first"],
   ["seen.last"] = mac_info["seen.last"],
   ["bytes.sent"] = mac_info["bytes.sent"],
   ["bytes.rcvd"] = mac_info["bytes.rcvd"],
   ["packets.sent"] = mac_info["packets.sent"],
   ["packets.rcvd"] = mac_info["packets.rcvd"],
   ["dhcp.sent"] = mac_info["dhcp.sent"],
   ["dhcp.rcvd"] = mac_info["dhcp.rcvd"],
   ["arp_requests.sent"] = mac_info["arp_requests.sent"],
   ["arp_requests.rcvd"] = mac_info["arp_requests.rcvd"],
   ["arp_replies.sent"] = mac_info["arp_replies.sent"],
   ["arp_replies.rcvd"] = mac_info["arp_replies.rcvd"],
   ["flows.dropped"] = mac_info["flows.dropped"],
   now = os.time(),
}

if _GET["counters"] == "true" then
   rest_utils.answer(rest_utils.consts.success.ok, counters)
   return
end

require "lua_utils_get"
local host_pools = require "host_pools"
local ifstats = interface.getStats()
local pools = host_pools:create()

local pool = pools:get_pool_by_member(mac)
local pool_id = pool and pool["pool_id"] or pools.DEFAULT_POOL_ID

-- The first host of the MAC (the page links it and the others)
local first_host
if (mac_info["num_hosts"] or 0) > 0 then
   for _, h in pairsByKeys(interface.getMacHosts(mac) or {}, asc) do
      first_host = { ip = h["ip"], vlan = h["vlan"] or 0 }
      break
   end
end

local symbolic = get_symbolic_mac(mac, true)
local first_observed = tonumber(ntop.getHashCache(getDevicesHashMapKey(interface.getId()), mac_info["mac"]))
local model = mac_info.model
if not isEmptyString(model) then
   -- discover_utils loads the locale (~30 ms): only for the MACs with a model
   model = require("discover_utils").apple_products[model] or model
end

local res = {
   mac = mac,
   symbolic_name = (symbolic ~= mac) and symbolic or nil,
   name = mac2label(mac),
   device_type = mac_info.devtype,
   model = model,
   ssid = mac_info.ssid,
   dhcp_fingerprint = mac_info.dhcp_fingerprint,
   location = mac_info.location,
   num_hosts = mac_info["num_hosts"],
   first_host = first_host,
   pool_id = pool_id,
   pool_name = pools:get_pool_name(pool_id),
   first_observed = first_observed,
   last_counter_reset = mac_info.last_counter_reset,
   events = mac_info.events,
   is_view = ifstats.isView or false,
   is_bridge = interface.isBridgeInterface(ifstats) or false,
   is_nedge = (ntop.isnEdge and ntop.isnEdge()) or false,
   is_admin = isAdministrator(),
}

for k, v in pairs(counters) do
   res[k] = v
end

rest_utils.answer(rest_utils.consts.success.ok, res)
