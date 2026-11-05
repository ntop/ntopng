--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Pause or resume the monitoring of an interface (administrators). The state is kept in the
-- same preference the old interface page used (ntopng.prefs.ifid_<id>_not_idle: "1" active,
-- "0" paused).
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "0", "active": "false"}' http://localhost:3000/lua/rest/v2/set/interface/idle_state.lua
--

-- http_lint: validates the JSON body (CSRF included) into _POST
require "http_lint"
require "ntop_utils"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ifid = _POST["ifid"]
local active = _POST["active"]

if isEmptyString(ifid) or isEmptyString(active) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

interface.select(ifid)
if tostring(interface.getId()) ~= tostring(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

-- Not for pcap files and nEdge netfilter queues (as the old page)
local ifstats = interface.getStats()
if interface.isPcapDumpInterface() or ifstats.type == "netfilter" then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

local is_active = (active == "true" or active == "1")
ntop.setPref("ntopng.prefs.ifid_" .. interface.getId() .. "_not_idle", is_active and "1" or "0")
interface.setInterfaceIdleState(not is_active)

rest_utils.answer(rest_utils.consts.success.ok, { is_paused = interface.isIdle() })
