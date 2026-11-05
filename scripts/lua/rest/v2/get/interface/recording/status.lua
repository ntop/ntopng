--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Status of the traffic recording (n2disk) of an interface (administrators, n2disk installed):
-- running or failed, the dump window, the recorded traffic and the last lines of the n2disk log
-- (most recent first). Epochs in seconds, bytes and packets as counters.
-- external: n2disk is run by hand (another provider), extraction tells if its data can be read
-- (status: OK, ERR_MISSING_TIMELINE, ERR_TIMELINE_PATH_NOT_EXISTING, ERR_UNABLE_TO_ACCESS_TIMELINE).
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/interface/recording/status.lua?ifid=0"
--

-- No lua_utils: http_lint validates _GET, recording_utils loads what it needs
require "http_lint"
require "ntop_utils"
local rest_utils = require "rest_utils"
local recording_utils = require "recording_utils"

local LOG_LINES = 32

if not recording_utils.isAvailable() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ifid = _GET["ifid"]
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
local external = recording_utils.getCurrentTrafficRecordingProvider(master_ifid) ~= "ntopng"
local enabled = external or recording_utils.isEnabled(master_ifid)
local running = enabled and recording_utils.isActive(master_ifid)

local function epoch(v)
   v = tonumber(v)
   return (v and v > 0) and v or nil
end

local res = { external = external, enabled = enabled, running = running }

if enabled then
   local stats = recording_utils.stats(master_ifid)
   res.first_epoch = epoch(stats.FirstDumpedEpoch)
   res.last_epoch = epoch(stats.LastDumpedEpoch)
   res.start_epoch = epoch(stats.StartEpoch)
   res.bytes = tonumber(stats.Bytes)
   res.packets = tonumber(stats.Packets)
   res.dropped = tonumber(stats.Dropped)

   local smart = recording_utils.smartStats(master_ifid)
   if smart.FirstDumpedEpoch ~= nil then
      res.smart = { first_epoch = epoch(smart.FirstDumpedEpoch), last_epoch = epoch(smart.LastDumpedEpoch) }
   end

   if external and running then
      local ok, _, status = recording_utils.checkExtraction(master_ifid)
      res.extraction = { ok = ok, status = status }
   end

   -- "<date> [n2disk]: <message>": only the message
   local log = {}
   for line in (recording_utils.log(master_ifid, LOG_LINES) or ""):gmatch("[^\n]+") do
      log[#log + 1] = line:match("%]: (.*)$") or line
   end
   res.log = log
end

rest_utils.answer(rest_utils.consts.success.ok, res)
