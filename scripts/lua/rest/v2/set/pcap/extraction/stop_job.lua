--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Stop a running traffic extraction job of an interface (administrators, n2disk installed):
-- the PCAP extracted so far is kept (status "stopped").
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "0", "job_id": "3"}' http://localhost:3000/lua/rest/v2/set/pcap/extraction/stop_job.lua
--

-- http_lint: validates the JSON body (CSRF included) into _POST
require "http_lint"
require "ntop_utils"
local rest_utils = require "rest_utils"
local recording_utils = require "recording_utils"

if not recording_utils.isAvailable() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ifid = _POST["ifid"]
if isEmptyString(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end
interface.select(ifid)
if tostring(interface.getId()) ~= tostring(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

-- Only a job of this interface
local job_id = tonumber(_POST["job_id"])
if not job_id or not recording_utils.getExtractionJobs(interface.getMasterInterfaceId())[job_id] then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

recording_utils.stopJob(job_id)
rest_utils.answer(rest_utils.consts.success.ok)
