--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Traffic extraction jobs of an interface (administrators, n2disk installed), newest first:
-- raw values (epochs, counters, status ids) for the Vue table of Interface details > Traffic
-- Recording > Jobs. status: waiting, waiting_nospace, processing, completed, stopped, failed
-- (error_code: why). files: the PCAP files to download (rest/v2/get/pcap/extraction/data.lua).
-- The DataTables version, with formatted values, is rest/v2/get/pcap/extraction/tasks.lua.
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/pcap/extraction/jobs.lua?ifid=0"
--

-- No lua_utils: http_lint validates _GET, recording_utils loads what it needs
require "http_lint"
require "ntop_utils"
local rest_utils = require "rest_utils"
local recording_utils = require "recording_utils"

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
if tostring(interface.getId()) ~= tostring(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

local res = {}
for _, job in pairs(recording_utils.getExtractionJobs(interface.getMasterInterfaceId())) do
   local done = job.status == "completed" or job.status == "stopped"
   -- Only a link of ntopng (set by the page that scheduled the job)
   local chart_url = job.chart_url
   if type(chart_url) ~= "string" or chart_url:sub(1, 1) ~= "/" or chart_url:sub(1, 2) == "//" then
      chart_url = nil
   end
   res[#res + 1] = {
      id = job.id,
      time = job.time,
      status = job.status,
      error_code = job.error_code,
      time_from = job.time_from,
      time_to = job.time_to,
      filter = job.filter or "",
      chart_url = chart_url,
      files = done and #recording_utils.getJobFiles(job.id) or 0,
      extracted_pkts = job.status == "completed" and job.extracted_pkts or nil,
      extracted_bytes = job.status == "completed" and job.extracted_bytes or nil,
   }
end
table.sort(res, function(a, b) return a.id > b.id end)

rest_utils.answer(rest_utils.consts.success.ok, res)
