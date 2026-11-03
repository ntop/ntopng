--
-- (C) 2013-26 - ntop.org
--
-- Live captures (pcap downloads) running on the interface
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "http_lint"
local rest_utils = require "rest_utils"

-- ?ifid= selects the interface; interface.select silently falls back to an allowed one: check it
local ifid = _GET["ifid"]
if not isEmptyString(ifid) then
   interface.select(tostring(ifid))
   if tostring(interface.getId()) ~= tostring(ifid) then
      rest_utils.answer(rest_utils.consts.err.invalid_interface)
      return
   end
end

-- Same right needed to start a live capture
if not ntop.isPcapDownloadAllowed() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local data = {}

for _, c in pairs(interface.dumpLiveCaptures() or {}) do
   data[#data + 1] = {
      id = c.id,
      host = c.host,
      num_captured_packets = c.num_captured_packets,
      capture_max_pkts = c.capture_max_pkts,
      capture_until = c.capture_until,
   }
end

rest_utils.answer(rest_utils.consts.success.ok, data)
