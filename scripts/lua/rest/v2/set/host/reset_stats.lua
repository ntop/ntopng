--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Resets the counters of an active host (administrators). JSON POST with the CSRF token.
-- resetstats_mode: reset_all (all the counters, default) or reset_blacklisted (only the blacklisted
-- flows/contacts counters).
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": 0, "host": "192.168.1.1@0", "resetstats_mode": "reset_all"}' http://localhost:3000/lua/rest/v2/set/host/reset_stats.lua
--

require "http_lint"
require "label_utils"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ifid = _POST["ifid"]
local host_key = _POST["host"]
local mode = _POST["resetstats_mode"] or "reset_all"

if isEmptyString(ifid) or isEmptyString(host_key) or (mode ~= "reset_all" and mode ~= "reset_blacklisted") then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

interface.select(tostring(ifid))
if tostring(interface.getId()) ~= tostring(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

local host_info = hostkey2hostinfo(host_key)
if interface.getHostInfo(host_info["host"], host_info["vlan"]) == nil then
   rest_utils.answer(rest_utils.consts.err.not_found)
   return
end

-- The key with the VLAN, as the old page (hostinfo2hostkey(host_info, nil, true))
local key = hostinfo2hostkey(host_info, nil, true)

if mode == "reset_blacklisted" then
   interface.resetHostStats(key, true)
elseif not interface.resetHostStats(key) then
   rest_utils.answer(rest_utils.consts.err.internal_error)
   return
end

rest_utils.answer(rest_utils.consts.success.ok)
