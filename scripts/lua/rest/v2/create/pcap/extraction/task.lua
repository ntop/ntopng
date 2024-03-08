--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local json = require("dkjson")
local recording_utils = require "recording_utils"

sendHTTPContentTypeHeader('application/json')

--
-- Schedule pcap extraction
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1", "epoch_begin": 1709888000, "epoch_end": 1709888100, "bpf_filter": ""}' http://localhost:3000/lua/rest/v2/create/pcap/extraction/task.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok

local res = {}

local ifid = _GET["ifid"]
local time_from = _POST["epoch_begin"] or _GET["epoch_begin"]
local time_to = _POST["epoch_end"] or _GET["epoch_end"]
local filter = _POST["bpf_filter"] or _GET["bpf_filter"]
local chart_url = _POST["url"] or _GET["url"]

if not recording_utils.isAvailable() then
   -- local error = i18n("traffic_recording.not_granted") 
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)

if time_from == nil or time_to == nil then
   -- local error = i18n("traffic_recording.missing_parameters")
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

local ifstats = interface.getStats()

time_from = tonumber(time_from)
time_to = tonumber(time_to)

local timeline_path = recording_utils.getTimelineByInterval(ifstats.id, time_from, time_to)

local params = {
      time_from = time_from,
      time_to = time_to,
      filter = filter,
      chart_url = chart_url,
      timeline_path = timeline_path
}

local job_info = recording_utils.scheduleExtraction(ifstats.id, params)

res.id = job_info.id

rest_utils.answer(rc, res)
