--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Traffic policy of a local host on an inline interface (administrators). JSON POST with the CSRF
-- token. action: block (drop all the host traffic), allow (stop dropping it), drop_flows (drop the
-- active flows of the host once).
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": 0, "host": "192.168.1.1@0", "action": "block"}' http://localhost:3000/lua/rest/v2/set/host/traffic_policy.lua
--

require "http_lint"
require "label_utils"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ACTIONS = { block = true, allow = true, drop_flows = true }
local ifid = _POST["ifid"]
local host_key = _POST["host"]
local action = _POST["action"]

if isEmptyString(ifid) or isEmptyString(host_key) or not ACTIONS[action or ""] then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

interface.select(tostring(ifid))
if tostring(interface.getId()) ~= tostring(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

-- Only inline interfaces can drop traffic
if not interface.getStats().inline then
   rest_utils.answer(rest_utils.consts.err.not_enabled)
   return
end

local host_ip = hostkey2hostinfo(host_key)["host"]
local h = interface.getHostInfo(host_ip, hostkey2hostinfo(host_key)["vlan"])
if h == nil or not h["localhost"] or h["is_multicast"] or h["is_broadcast"] then
   rest_utils.answer(rest_utils.consts.err.not_found)
   return
end

-- The policy is per IP (ntopng.prefs.drop_host_traffic), as the old page
if action == "drop_flows" then
   interface.dropHostTraffic(host_ip)
else
   if action == "block" then
      ntop.setHashCache("ntopng.prefs.drop_host_traffic", host_ip, "true")
   else
      ntop.delHashCache("ntopng.prefs.drop_host_traffic", host_ip)
   end
   interface.updateHostTrafficPolicy(host_ip, 0)
end

rest_utils.answer(rest_utils.consts.success.ok, {
   blocked = (ntop.getHashCache("ntopng.prefs.drop_host_traffic", host_ip) == "true"),
})
