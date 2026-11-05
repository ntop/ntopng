--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Delete a traffic extraction job of an interface and its PCAP files (administrators, n2disk
-- installed). all=true instead of job_id: every job of the interface (the running ones are stopped).
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "0", "job_id": "3"}' http://localhost:3000/lua/rest/v2/delete/pcap/extraction/job.lua
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
local master_ifid = interface.getMasterInterfaceId()

if _POST["all"] == "true" or _POST["all"] == "1" then
   recording_utils.deleteAndStopAllJobs(master_ifid)
   rest_utils.answer(rest_utils.consts.success.ok)
   return
end

-- Only a job of this interface
local job_id = tonumber(_POST["job_id"])
if not job_id or not recording_utils.getExtractionJobs(master_ifid)[job_id] then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

recording_utils.deleteJob(job_id)
rest_utils.answer(rest_utils.consts.success.ok)
